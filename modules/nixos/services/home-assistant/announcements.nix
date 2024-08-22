{
  lib,
  config,
  inputs,
  ...
}:
let
  inherit (lib)
    types
    mkOption
    mkIf
    optional
    singleton
    mkMerge
    concatMap
    hasInfix
    utils
    ;
  inherit (secrets.general) devices userIds peopleList;
  cfg = config.modules.services.hass;
  secrets = inputs.nix-resources.secrets.hass { inherit lib config; };
in
{
  options.modules.services.hass.homeAnnouncements.lovelaceView = mkOption {
    type = types.attrs;
    description = "Lovelace view for home announcements";
    readOnly = true;
    default = {
      title = "Announcements";
      path = "announcements";
      type = "sections";
      max_columns = 2;
      sections = [
        {
          title = "Controls";
          type = "grid";
          cards =
            [
              {
                name = "Send Announcement";
                type = "button";
                icon = "mdi:bell";
                tap_action = {
                  action = "perform-action";
                  perform_action = "script.send_announcement";
                };
                visibility = singleton {
                  condition = "state";
                  entity = "script.send_announcement";
                  state = "off";
                };
                layout_options = {
                  grid_columns = 2;
                  grid_rows = 2;
                };
              }
              {
                name = "Sending Announcements...";
                type = "button";
                icon = "mdi:send-circle";
                tap_action.action = "none";
                hold_action.action = "none";
                visibility = singleton {
                  condition = "state";
                  entity = "script.send_announcement";
                  state = "on";
                };
                layout_options = {
                  grid_columns = 2;
                  grid_rows = 2;
                };
              }
              {
                type = "entity";
                name = "Message";
                entity = "input_text.announcement_message";
              }
            ]
            ++ (map (person: {
              type = "tile";
              entity = "input_boolean.${person}_announcement_enable";
              name = utils.upperFirstChar person;
              tap_action.action = "toggle";
            }) peopleList);
        }
        {
          title = "Responses";
          type = "grid";
          cards = concatMap (
            person:
            (
              (map
                (variant: {
                  type = "tile";
                  entity = "input_text.${person}_announcement_response";
                  name = utils.upperFirstChar person;
                  inherit (variant) color;
                  visibility = singleton {
                    condition = "state";
                    entity = "input_text.${person}_announcement_response";
                    inherit (variant) state;
                  };
                })
                [
                  {
                    state = "I'm coming";
                    color = "green";
                  }
                  {
                    state = "Awaiting response";
                    color = "amber";
                  }
                  {
                    state = "I'll be delayed";
                    color = "cyan";
                  }
                  {
                    state = "No response";
                    color = "red";
                  }
                ]
              )
              ++ singleton {
                type = "tile";
                entity = "input_text.${person}_announcement_response";
                name = utils.upperFirstChar person;
                color = "blue";
                visibility = singleton {
                  condition = "and";
                  conditions =
                    map
                      (state: {
                        condition = "state";
                        entity = "input_text.${person}_announcement_response";
                        state_not = state;
                      })
                      [
                        "I'm coming"
                        "Awaiting response"
                        "I'll be delayed"
                        "No response"
                      ];
                };
              }
            )
          ) peopleList;
        }
      ];
    };
  };

  config = mkIf cfg.enableInternal {
    services.home-assistant.config = mkMerge (
      singleton {
        script.send_announcement = {
          alias = "Send Announcement";
          sequence = singleton {
            parallel = (
              (map (
                person:
                let
                  device = devices.${person};
                  isAndroid = !(hasInfix "iphone" device.name);
                in
                {
                  sequence = [
                    {
                      action = "input_text.set_value";
                      target.entity_id = "input_text.${person}_announcement_response";
                      data.value = "No response";
                    }
                    {
                      action = "input_boolean.turn_off";
                      target.entity_id = "input_boolean.${person}_announcement_acknowledged";
                    }
                    {
                      condition = "template";
                      # Allow self-triggering announcements ourselves for debugging
                      value_template = "{{ context.user_id == '${userIds."joshua"}' or context.user_id != '${userIds.${person}}' }}";
                    }
                    {
                      condition = "state";
                      entity_id = "input_boolean.${person}_announcement_enable";
                      state = "on";
                    }
                    {
                      repeat = {
                        count = 5;
                        sequence = [
                          {
                            condition = "state";
                            entity_id = "input_boolean.${person}_announcement_acknowledged";
                            state = "off";
                          }
                          {
                            alias = "Send the announcement notification";
                            action = "notify.mobile_app_${device.name}";
                            data = {
                              title = "{{ states('input_text.announcement_message') }}";
                              message = if (!isAndroid) then "Tap and hold to reply" else "Select a reply";
                              data = mkMerge [
                                {
                                  context_id = "{{ 'CONTEXT_' ~ context.id }}";
                                  tag = "household-announcement";
                                  actions = [
                                    {
                                      action = "COMING";
                                      title = "I'm coming";
                                    }
                                    {
                                      action = "DELAYED";
                                      title = "I'll be delayed";
                                    }
                                    {
                                      action = "REPLY";
                                      title = "Custom reply";
                                    }
                                  ];
                                }

                                (mkIf isAndroid {
                                  sticky = true;
                                  priority = "high";
                                  ttl = 0;
                                  channel = "Household Announcement";
                                  importance = "high";
                                  visibility = "public";
                                })

                                (mkIf (!isAndroid) {
                                  activationMode = "background";
                                  authenticationRequired = false;
                                  push.interruption-level = "critical";
                                })
                              ];
                            };
                          }
                          {
                            action = "input_text.set_value";
                            target.entity_id = "input_text.${person}_announcement_response";
                            data.value = "Awaiting response";
                          }
                          {
                            wait_for_trigger = [
                              {
                                platform = "event";
                                event_type = "mobile_app_notification_action";
                                event_data.action = "COMING";
                                context.user_id = [ userIds.${person} ];
                              }
                              {
                                platform = "event";
                                event_type = "mobile_app_notification_action";
                                event_data.action = "DELAYED";
                                context.user_id = [ userIds.${person} ];
                              }
                              {
                                platform = "event";
                                event_type = "mobile_app_notification_action";
                                event_data.action = "REPLY";
                                context.user_id = [ userIds.${person} ];
                              }
                            ];
                            timeout.seconds = 60;
                          }
                          {
                            "if" = singleton {
                              condition = "template";
                              value_template = "{{ wait.trigger != none }}";
                            };
                            "then" =
                              [
                                {
                                  action = "input_boolean.turn_on";
                                  target.entity_id = "input_boolean.${person}_announcement_acknowledged";
                                }
                                {
                                  action = "input_text.set_value";
                                  target.entity_id = "input_text.${person}_announcement_response";
                                  data.value = ''
                                    {% if wait.trigger.event.data.action == 'COMING' %}
                                      I'm coming
                                    {% elif wait.trigger.event.data.action == 'DELAYED' %}
                                      I'll be delayed
                                    {% else %}
                                      {{ wait.trigger.event.data.reply_text }}
                                    {% endif %}
                                  '';
                                }
                              ]
                              ++ optional isAndroid {
                                alias = "Clear the sticky notification on Android";
                                action = "notify.mobile_app_${device.name}";
                                data = {
                                  message = "clear_notification";
                                  data.tag = "household-announcement";
                                };
                              };
                          }
                        ];
                      };
                    }
                    {
                      condition = "state";
                      entity_id = "input_boolean.${person}_announcement_acknowledged";
                      state = "off";
                    }
                    {
                      action = "input_text.set_value";
                      target.entity_id = "input_text.${person}_announcement_response";
                      data.value = "No response";
                    }
                  ];
                }
              ) peopleList)
              ++ singleton {
                action = "notify.lounge_tv";
                data.message = "{{ states('input_text.announcement_message') }}";
              }
            );
          };
        };

        input_text.announcement_message = {
          name = "Announcement Message";
          initial = "Dinner is ready";
        };
      }
      ++ (map (person: {
        input_text."${person}_announcement_response" = {
          name = "${utils.upperFirstChar person} Announcement Response";
          icon = "mdi:account";
          initial = "No response";
        };

        input_boolean = {
          "${person}_announcement_enable" = {
            name = "${utils.upperFirstChar person} Announcement Enable";
            icon = "mdi:bell";
          };
          "${person}_announcement_acknowledged" = {
            name = "${utils.upperFirstChar person} Announcement Acknowledged";
          };
        };
      }) peopleList)
    );

  };
}
