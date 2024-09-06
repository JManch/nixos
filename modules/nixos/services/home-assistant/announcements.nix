{
  ns,
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
    ;
  inherit (lib.${ns}) upperFirstChar;
  inherit (secrets.general) devices userIds peopleList;
  cfg = config.${ns}.services.hass;
  secrets = inputs.nix-resources.secrets.hass { inherit lib config; };
in
{
  options.${ns}.services.hass.homeAnnouncements.lovelaceView = mkOption {
    type = types.attrs;
    description = "Lovelace view for home announcements";
    readOnly = true;
    default = {
      title = "Announcements";
      path = "announcements";
      type = "sections";
      max_columns = 2;
      badges = concatMap (
        person:
        let
          inherit (devices.${person}) isAndroid;
          device = devices.${person}.name;
        in
        optional isAndroid {
          type = "entity";
          entity = "sensor.${device}_ringer_mode";
          icon = "mdi:bell-off";
          color = "red";
          name = "${upperFirstChar person}'s Phone is Silent";
          state_content = "name";
          visibility = singleton {
            condition = "or";
            conditions = [
              {
                condition = "numeric_state";
                entity = "sensor.${device}_volume_level_notification";
                below = 1;
              }
              {
                condition = "state";
                entity = "sensor.${device}_ringer_mode";
                state = "silent";
              }
              {
                condition = "state";
                entity = "sensor.${device}_ringer_mode";
                state = "vibrate";
              }
              {
                condition = "state";
                entity = "sensor.${device}_do_not_disturb_sensor";
                state_not = "off";
              }
            ];
          };
        }
      ) peopleList;
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
            ++ (concatMap (person: [
              {
                type = "tile";
                entity = "input_boolean.${person}_announcement_enable";
                name = upperFirstChar person;
                tap_action.action = "toggle";
                visibility = singleton {
                  condition = "state";
                  entity = "person.${person}";
                  state = "home";
                };
              }
              {
                type = "tile";
                entity = "person.${person}";
                visibility = singleton {
                  condition = "state";
                  entity = "person.${person}";
                  state = "not_home";
                };
              }
            ]) peopleList);
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
                  name = upperFirstChar person;
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
                name = upperFirstChar person;
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
                  inherit (device) isAndroid;
                  device = devices.${person};
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
                      condition = "state";
                      entity_id = "person.${person}";
                      state = "home";
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
                            variables = {
                              action_coming = "{{ 'COMING_' ~ context.id }}";
                              action_delayed = "{{ 'DELAYED_' ~ context.id }}";
                              # WARN: Ideally we would use context.id here but that breaks the reply
                              # functionality. It can be worked around on Android by checking the tag in
                              # the app notification action but this is not possible on ios. I'll just have
                              # to hope REPLY actions don't happen simultaneously.
                              action_reply = "REPLY";
                            };
                          }
                          {
                            alias = "Send the announcement notification";
                            action = "notify.mobile_app_${device.name}";
                            data = {
                              title = "{{ states('input_text.announcement_message') }}";
                              message = if (!isAndroid) then "Tap and hold to reply" else "Select a reply";
                              data = mkMerge [
                                {
                                  tag = "household-announcement";
                                  actions = [
                                    {
                                      action = "{{ action_coming }}";
                                      title = "I'm coming";
                                    }
                                    {
                                      action = "{{ action_delayed }}";
                                      title = "I'll be delayed";
                                    }
                                    {
                                      action = "{{ action_reply }}";
                                      title = "Custom reply";
                                    }
                                  ];
                                }

                                (mkIf isAndroid {
                                  sticky = true;
                                  ttl = 0;
                                  channel = "Household Announcement";
                                  importance = "high";
                                  priority = "high";
                                  visibility = "public";
                                })

                                (mkIf (!isAndroid) {
                                  activationMode = "background";
                                  authenticationRequired = false;
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
                                event_data.action = "{{ action_coming }}";
                                event_data.tag = mkIf isAndroid "household-announcement";
                                context.user_id = [ userIds.${person} ];
                              }
                              {
                                platform = "event";
                                event_type = "mobile_app_notification_action";
                                event_data.action = "{{ action_delayed }}";
                                event_data.tag = mkIf isAndroid "household-announcement";
                                context.user_id = [ userIds.${person} ];
                              }
                              {
                                platform = "event";
                                event_type = "mobile_app_notification_action";
                                event_data.action = "{{ action_reply }}";
                                # This is only possible here because we're using Nix so we have more control
                                # over config generation. In pure yaml context it isn't possible to
                                # conditionally add tag depending on android vs ios like this. We might as well
                                # take advantage of it to make replies unique on Android.
                                event_data.tag = mkIf isAndroid "household-announcement";
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
                                    {% if wait.trigger.event.data.action == action_coming %}
                                      I'm coming
                                    {% elif wait.trigger.event.data.action == action_delayed %}
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
          name = "${upperFirstChar person} Announcement Response";
          icon = "mdi:account";
          initial = "No response";
        };

        input_boolean = {
          "${person}_announcement_enable" = {
            name = "${upperFirstChar person} Announcement Enable";
            icon = "mdi:bell";
          };
          "${person}_announcement_acknowledged" = {
            name = "${upperFirstChar person} Announcement Acknowledged";
          };
        };
      }) peopleList)
    );
  };
}
