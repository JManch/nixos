# Config sets are options that configure multiple elements in a system. This
# can include templates, automations, input helpers etc... It's useful for
# applying variations of a system to multiple rooms without duplicating code.
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
    optionals
    singleton
    attrValues
    mkMerge
    concatMapStringsSep
    concatMap
    hasInfix
    utils
    splitString
    mkEnableOption
    ;
  inherit (secrets.general)
    people
    devices
    userIds
    peopleList
    ;
  cfg = config.modules.services.hass;
  secrets = inputs.nix-resources.secrets.hass { inherit lib config; };
in
{
  options.modules.services.hass = {
    smartLightingRooms = mkOption {
      description = ''
        List of rooms to configure modular smart lighting functionality for.
        Also generates  lovelace cards that can be added to the dashboard.
        Smart lighting features include: (1) adaptive lighting that changes
        lighting color and brightness to match the sun (in bedrooms, the
        adaptive lighting schedule is synced with the users wake-up and
        sleep-time determined from their next phone alarm and desired sleep
        duration configured in the dashboard), (2) wake-up lighting that
        automatically turns on the lights 1 hour before wake-up time and
        gradually increases brightness, (3) automated lighting toggle based on
        presence in the room and the natural outdoor brightness (inferred from
        solar power generation), and (4), automated sleep mode that dims the
        brightness and optionally turns off certain lights when the user's
        phone is placed on charge around sleep time.
      '';
      default = [ ];
      type = types.attrsOf (
        types.submodule (
          { config, ... }:
          {
            options = {
              roomId = mkOption {
                type = types.str;
                example = "joshua_room";
              };

              roomDeviceId = mkOption {
                type = types.str;
                example = "joshua_pixel_5";
                description = ''
                  Mobile device associated with the room owner. Used for
                  alarm time in wake-up lights and charging status for
                  enabling sleep mode.
                '';
              };

              wakeUpLights = {
                enable = mkEnableOption ''
                  automatically turning on the lights 1 hour before the
                  alarm/wake-up time
                '';
                type = mkOption {
                  type = types.enum [
                    "alarm"
                    "manual"
                  ];
                  default = "manual";
                  description = ''
                    The method used for determining the wake-up time. Alarm using
                    the next alarm sensor from the `roomDeviceId` device (android
                    only). Manual gets the wake-up time from a datetime input on
                    the dashboard.
                  '';
                };
              };

              adaptiveLighting = {
                enable = mkEnableOption "adaptive lighting";

                lights = mkOption {
                  type = with types; nullOr (listOf str);
                  default = null;
                  description = ''
                    Lights that adaptive lighting controls. When null adaptive
                    lighting controls all lights in the room as a group. This is
                    preferred as it results in less zigbee network traffic.
                  '';
                };

                takeOverControl =
                  mkEnableOption ''
                    allowing manual controls to override adaptive lighting. This
                    should only be enabled if really necessary as it has a
                    performance impact.
                  ''
                  // {
                    default = false;
                  };

                minBrightness = mkOption {
                  type = types.int;
                  default = 20;
                };

                sleepMode = {
                  automate = mkEnableOption ''
                    automated sleep mode. Sleep mode enables 1 hour after sleep
                    time (or earlier if phone is plugged in time t satisfies
                    `sleep_time - 30mins <= t < wake_up_time - 1hour`). Sleep
                    mode always disables 1 hour before wake-up time.
                  '';

                  disabledLights = mkOption {
                    type = with types; listOf str;
                    default = [ ];
                    example = [ "light.joshua_bulb_ceiling" ];
                    description = "Entity ids of lights to turn off when sleep mode is enabled";
                  };

                  color = mkOption {
                    type = with types; nullOr (listOf int);
                    default = null;
                    example = [
                      255
                      0
                      0
                    ];
                    description = "Sleep mode rgb color. Leave null to use color temp";
                  };
                };
              };

              automatedToggle = {
                enable = mkEnableOption ''
                  automaticlly toggle the lights based on outdoor solar generation.
                  Requires some sort of presence detection in the room.
                '';

                presenceTriggers = mkOption {
                  type = with types; listOf attrs;
                  example = singleton {
                    platform = "state";
                    entity_id = "binary_sensor.ncase_m1_active";
                    from = null;
                  };
                  description = ''
                    Custom additional triggers that signify a change to presence
                    in the room. This can be presence enabling or disabling. Must
                    be used in conjunction with `presenceConditions` and
                    `noPresenceConditions` to have an effect.
                  '';
                };

                presenceConditions = mkOption {
                  type = with types; listOf attrs;
                  example = [
                    {
                      condition = "state";
                      entity_id = "binary_sensor.ncase_m1_active";
                      state = "on";
                    }
                  ];
                  description = ''
                    Conditions for room presence that signifies lights should be
                    turned on
                  '';
                };

                noPresenceConditions = mkOption {
                  type = with types; listOf attrs;
                  example = [
                    {
                      condition = "state";
                      entity_id = "binary_sensor.ncase_m1_active";
                      state = "off";
                    }
                  ];
                  description = ''
                    Conditions for no room presence that signifies lights should
                    be turned off
                  '';
                };
              };

              lovelaceCards = mkOption {
                type = with types; functionTo (listOf attrs);
                readOnly = true;
                default =
                  let
                    inherit (config) adaptiveLighting roomId wakeUpLights;
                  in
                  {
                    individualLights ? [ ],
                    floorPlanLights ? null,
                  }:
                  [
                    {
                      type = "button";
                      name = "Toggle";
                      entity = "light.${roomId}_lights";
                      tap_action.action = "toggle";
                      layout_options = {
                        grid_columns = 1;
                        grid_rows = 3;
                      };
                    }
                    {
                      type = "tile";
                      entity = "light.${roomId}_lights";
                      name = "All Lights";
                      layout_options = {
                        grid_columns = 3;
                        grid_rows = 3;
                      };
                      features = [
                        { type = "light-brightness"; }
                        { type = "light-color-temp"; }
                      ];
                    }
                  ]
                  ++ (
                    if (floorPlanLights != null) then
                      singleton {
                        camera_image = "camera.${roomId}_floorplan";
                        type = "picture-elements";
                        elements = floorPlanLights;
                      }
                    else
                      (map (l: {
                        type = "tile";
                        entity = "light.${l}";
                        tap_action.action = "toggle";
                        visibility = singleton {
                          condition = "state";
                          entity = "light.${l}";
                          state_not = "unavailable";
                        };
                      }) individualLights)
                  )
                  ++ optionals adaptiveLighting.enable [
                    {
                      name = "Adaptive Lighting";
                      type = "tile";
                      entity = "switch.adaptive_lighting_${roomId}";
                      tap_action.action = "toggle";
                      layout_options = {
                        grid_columns = 4;
                        grid_rows = 1;
                      };
                    }
                  ]
                  ++ optionals wakeUpLights.enable (
                    [
                      {
                        name = "Wake Up Lights";
                        type = "tile";
                        entity = "input_boolean.${roomId}_wake_up_lights";
                        tap_action.action = "toggle";
                        layout_options = {
                          grid_columns = 2;
                          grid_rows = 1;
                        };
                      }
                    ]
                    ++ [
                      {
                        name = "Sleep Duration";
                        type = "tile";
                        entity = "input_number.${roomId}_sleep_duration";
                        layout_options = {
                          grid_columns = 2;
                          grid_rows = 1;
                        };
                      }
                    ]
                  )
                  ++ optional adaptiveLighting.enable {
                    name = "Sleep Mode";
                    type = "tile";
                    entity = "switch.adaptive_lighting_sleep_mode_${roomId}";
                    tap_action.action = "toggle";
                    layout_options = {
                      grid_columns = if (wakeUpLights.enable && wakeUpLights.type == "manual") then 2 else 4;
                      grid_rows = 1;
                    };
                  }
                  ++ optional (wakeUpLights.enable && wakeUpLights.type == "manual") {
                    name = "Wake Up Time";
                    type = "tile";
                    entity = "input_datetime.${roomId}_wake_up_time";
                    layout_options = {
                      grid_columns = 2;
                      grid_rows = 1;
                    };
                  };
              };
            };
          }
        )
      );
    };

    homeAnnouncements.lovelaceView = mkOption {
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
  };

  config = mkIf cfg.enableInternal {
    services.home-assistant.config = mkMerge (
      (map (
        cfg':
        let
          formattedRoomName = concatMapStringsSep " " (s: utils.upperFirstChar s) (
            splitString "_" cfg'.roomId
          );

          wakeUpTimestamp =
            if cfg'.wakeUpLights.type == "alarm" then
              "as_timestamp(states('sensor.${cfg'.roomDeviceId}_next_alarm'), default = 0) | round(0)"
            else
              "as_timestamp(today_at(states('input_datetime.${cfg'.roomId}_wake_up_time')), default = 0) | round(0)";

          sleepDuration = "(states('input_number.${cfg'.roomId}_sleep_duration') | float(8))";
        in
        mkMerge [
          (mkIf cfg'.wakeUpLights.enable {
            automation =
              singleton {
                alias = "${formattedRoomName} Wake Up Lights";
                trace.stored_traces = 5;
                mode = "single";
                trigger = singleton {
                  platform = "template";
                  value_template = "{{ (now().timestamp() + 60*60) | round(0) == ${wakeUpTimestamp} }}";
                };
                condition = singleton {
                  condition = "state";
                  entity_id = "input_boolean.${cfg'.roomId}_wake_up_lights";
                  state = "on";
                };
                action = singleton {
                  action = "light.turn_on";
                  target.entity_id = "light.${cfg'.roomId}_lights";
                };
              }
              ++ optional cfg'.adaptiveLighting.enable {
                alias = "${formattedRoomName} Lighting Sun Times";
                trace.stored_traces = 5;
                mode = "single";
                trigger =
                  [
                    {
                      platform = "homeassistant";
                      event = "start";
                    }
                    {
                      platform = "state";
                      entity_id = [ "input_number.${cfg'.roomId}_sleep_duration" ];
                      from = null;
                    }
                  ]
                  ++ (
                    if (cfg'.wakeUpLights.type == "manual") then
                      singleton {
                        platform = "state";
                        entity_id = [ "input_datetime.${cfg'.roomId}_wake_up_time" ];
                        from = null;
                      }
                    else
                      [
                        {
                          platform = "state";
                          entity_id = [ "sensor.${cfg'.roomDeviceId}_next_alarm" ];
                          from = null;
                        }
                        {
                          platform = "state";
                          entity_id = [ "sensor.${cfg'.roomDeviceId}_next_alarm" ];
                          to = "unavailable";
                          for.minutes = 5;
                        }
                      ]
                  );
                action =
                  let
                    unavailableConditions =
                      addFor:
                      singleton {
                        condition = "state";
                        entity_id = "input_number.${cfg'.roomId}_sleep_duration";
                        state = "unavailable";
                      }
                      ++ singleton (
                        if (cfg'.wakeUpLights.type == "alarm") then
                          {
                            condition = "state";
                            entity_id = "sensor.${cfg'.roomDeviceId}_next_alarm";
                            state = "unavailable";
                            # Alarm has to be unavailable for 5 minutes for it to be considered unavailable
                            # and for adaptive lighting to be reset to default. This is because when the
                            # alarm goes off, it always becomes unavailable for a few seconds and if this
                            # reset the lights it potentially flashbangs you when waking up.
                            for = mkIf addFor { minutes = 5; };
                          }
                        else
                          {
                            condition = "state";
                            entity_id = "input_datetime.${cfg'.roomId}_wake_up_time";
                            state = "unavailable";
                          }
                      );
                  in
                  singleton {
                    choose = [
                      {
                        conditions = singleton {
                          condition = "not";
                          conditions = unavailableConditions false;
                        };
                        sequence = singleton {
                          action = "adaptive_lighting.change_switch_settings";
                          data = {
                            entity_id = "switch.adaptive_lighting_${cfg'.roomId}";
                            use_defaults = "current";
                            sunrise_time = "{{ ${wakeUpTimestamp} | timestamp_custom('%H:%M:%S') }}";
                            # Set sunset 1.5 hours before sleep time so that lights
                            # will reach minimum brightness at sleep time
                            sunset_time = "{{ (${wakeUpTimestamp} - (${sleepDuration} + 1.5)*60*60) | timestamp_custom('%H:%M:%S') }}";
                          };
                        };
                      }
                      {
                        conditions = singleton {
                          condition = "or";
                          conditions = unavailableConditions true;
                        };
                        sequence = singleton {
                          action = "adaptive_lighting.change_switch_settings";
                          data = {
                            entity_id = "switch.adaptive_lighting_${cfg'.roomId}";
                            use_defaults = "configuration";
                          };
                        };
                      }
                    ];
                  };
              };

            input_boolean."${cfg'.roomId}_wake_up_lights" = {
              name = "${formattedRoomName} Wake Up Lights";
              icon = "mdi:weather-sunset-up";
            };

            input_datetime = mkIf (cfg'.wakeUpLights.type == "manual") {
              "${cfg'.roomId}_wake_up_time" = {
                name = "${formattedRoomName} Wake Up Time";
                has_time = true;
              };
            };

            input_number."${cfg'.roomId}_sleep_duration" = {
              name = "${formattedRoomName} Sleep Duration";
              initial = 8;
              min = 5;
              max = 11;
              step = 0.5;
              icon = "mdi:bed-clock";
              unit_of_measurement = "h";
            };
          })

          (mkIf cfg'.adaptiveLighting.enable {
            adaptive_lighting = singleton {
              name = "${formattedRoomName} ";
              lights =
                if cfg'.adaptiveLighting.lights == null then
                  [ "light.${cfg'.roomId}_lights" ]
                else
                  cfg'.adaptiveLighting.lights;
              min_brightness = cfg'.adaptiveLighting.minBrightness;
              sleep_brightness = 5;
              sunrise_time = "07:00:00";
              sunset_time = "22:30:00";
              brightness_mode = "tanh";
              brightness_mode_time_dark = 3600;
              brightness_mode_time_light = 900;
              take_over_control = cfg'.adaptiveLighting.takeOverControl;
              skip_redundant_commands = true;
              sleep_rgb_or_color_temp =
                if (cfg'.adaptiveLighting.sleepMode.color == null) then "color_temp" else "rgb_color";
              sleep_color_temp = mkIf (cfg'.adaptiveLighting.sleepMode.color == null) 1000;
              sleep_rgb_color = mkIf (
                cfg'.adaptiveLighting.sleepMode.color != null
              ) cfg'.adaptiveLighting.sleepMode.color;
            };

            automation =
              optional (cfg'.adaptiveLighting.sleepMode.disabledLights != [ ]) {
                alias = "${formattedRoomName} Sleep Mode Lights Toggle";
                trace.stored_traces = 5;
                mode = "single";
                trigger = [
                  {
                    platform = "state";
                    entity_id = [ "switch.adaptive_lighting_sleep_mode_${cfg'.roomId}" ];
                    from = null;
                  }
                  {
                    platform = "state";
                    entity_id = [ "light.${cfg'.roomId}_lights" ];
                    to = "on";
                    id = "lights_on";
                  }
                ];
                condition = singleton {
                  condition = "state";
                  entity_id = "switch.adaptive_lighting_${cfg'.roomId}";
                  state = "on";
                };
                action = [
                  { delay.seconds = 2; }
                  {
                    choose = [
                      {
                        conditions = singleton {
                          condition = "state";
                          entity_id = "switch.adaptive_lighting_sleep_mode_${cfg'.roomId}";
                          state = "on";
                        };
                        sequence = singleton {
                          action = "light.turn_off";
                          target.entity_id = cfg'.adaptiveLighting.sleepMode.disabledLights;
                        };
                      }
                      {
                        conditions = singleton {
                          condition = "and";
                          conditions = [
                            {
                              condition = "state";
                              entity_id = "switch.adaptive_lighting_sleep_mode_${cfg'.roomId}";
                              state = "off";
                            }
                            {
                              condition = "state";
                              entity_id = "light.${cfg'.roomId}_lights";
                              state = "on";
                            }
                            {
                              condition = "not";
                              conditions = singleton {
                                condition = "trigger";
                                id = [ "lights_on" ];
                              };
                            }
                          ];
                        };
                        sequence = singleton {
                          action = "light.turn_on";
                          target.entity_id = cfg'.adaptiveLighting.sleepMode.disabledLights;
                        };
                      }
                    ];
                  }
                ];
              }
              ++ optional (cfg'.adaptiveLighting.sleepMode.automate && cfg'.wakeUpLights.enable) {
                alias = "${formattedRoomName} Sleep Mode Toggle";
                trace.stored_traces = 5;
                mode = "single";
                trigger =
                  [
                    {
                      platform = "state";
                      entity_id = [ "binary_sensor.${cfg'.roomDeviceId}_is_charging" ];
                      from = "off";
                      to = "on";
                    }
                    {
                      # 1 hour before wake-up time (1 min earlier to run before wake-up lights)
                      platform = "template";
                      value_template = "{{ (now().timestamp() + 61*60) | round(0) == ${wakeUpTimestamp} }}";
                    }
                    {
                      # 1 hour after sleep time
                      platform = "template";
                      value_template = "{{ (now().timestamp() + (${sleepDuration} - 1)*60*60) | round(0) == ${wakeUpTimestamp} }}";
                    }
                    {
                      platform = "state";
                      entity_id = [ "input_number.${cfg'.roomId}_sleep_duration" ];
                      from = null;
                    }
                  ]
                  ++ singleton (
                    if (cfg'.wakeUpLights.type == "manual") then
                      {
                        platform = "state";
                        entity_id = [ "input_datetime.${cfg'.roomId}_wake_up_time" ];
                        from = null;
                      }
                    else
                      {
                        platform = "state";
                        entity_id = [ "sensor.${cfg'.roomDeviceId}_next_alarm" ];
                        from = null;
                      }
                  );
                condition = singleton {
                  condition = "state";
                  entity_id = "switch.adaptive_lighting_${cfg'.roomId}";
                  state = "on";
                };
                action = singleton {
                  choose =
                    let
                      timeToWake = "(${wakeUpTimestamp} - (now().timestamp() | round(0)))";
                    in
                    [
                      {
                        conditions = singleton {
                          condition = "template";
                          value_template = "{{ (${wakeUpTimestamp} != 0) and (${timeToWake} <= ((${sleepDuration} + 0.5)*60*60) + 60) and (${timeToWake} > 61*60) }}";
                        };
                        sequence = singleton {
                          action = "switch.turn_on";
                          target.entity_id = "switch.adaptive_lighting_sleep_mode_${cfg'.roomId}";
                        };
                      }
                      {
                        conditions = singleton {
                          condition = "template";
                          value_template = "{{ (${wakeUpTimestamp} == 0) or (${timeToWake} > ((${sleepDuration} + 0.5)*60*60) + 60) or (${timeToWake} <= 61*60) }}";
                        };
                        sequence = singleton {
                          action = "switch.turn_off";
                          target.entity_id = "switch.adaptive_lighting_sleep_mode_${cfg'.roomId}";
                        };
                      }
                    ];
                };
              };
          })

          (mkIf cfg'.automatedToggle.enable {
            automation = singleton {
              alias = "${formattedRoomName} Lights Toggle";
              trace.stored_traces = 5;
              mode = "queued";
              trigger = [
                {
                  platform = "numeric_state";
                  entity_id = [ "sensor.smoothed_solar_power" ];
                  above = 2;
                  id = "solar";
                }
                {
                  platform = "numeric_state";
                  entity_id = [ "sensor.smoothed_solar_power" ];
                  below = 2;
                  id = "solar";
                }
              ] ++ cfg'.automatedToggle.presenceTriggers;
              condition = singleton {
                condition = "numeric_state";
                entity_id = "sensor.${cfg'.roomDeviceId}_sleep_confidence";
                below = 90;
              };
              action =
                let
                  solarCondition = below: {
                    condition = "numeric_state";
                    entity_id = "sensor.smoothed_solar_power";
                    below = mkIf below 2;
                    above = mkIf (!below) 2;
                  };
                in
                singleton {
                  "if" = singleton {
                    condition = "and";
                    conditions = [
                      {
                        condition = "state";
                        entity_id = "light.${cfg'.roomId}_lights";
                        state = "off";
                      }
                      (solarCondition true)
                    ] ++ cfg'.automatedToggle.presenceConditions;
                  };
                  "then" = singleton {
                    action = "light.turn_on";
                    target.entity_id = "light.${cfg'.roomId}_lights";
                  };
                  "else" = [
                    # It's important to delay before checking conditions as
                    # state can change during the delay
                    { delay.seconds = 30; }
                    {
                      "if" = singleton {
                        condition = "and";
                        conditions = [
                          {
                            condition = "state";
                            entity_id = "light.${cfg'.roomId}_lights";
                            state = "on";
                          }
                          {
                            condition = "or";
                            conditions = [
                              (solarCondition false)
                              {
                                condition = "not";
                                conditions = singleton {
                                  condition = "trigger";
                                  id = [ "solar" ];
                                };
                              }
                            ];
                          }
                        ] ++ cfg'.automatedToggle.noPresenceConditions;
                      };
                      "then" = singleton {
                        action = "light.turn_off";
                        target.entity_id = "light.${cfg'.roomId}_lights";
                      };
                    }
                  ];
                };
            };
          })
        ]
      ) (attrValues cfg.smartLightingRooms))
      ++ singleton {
        script.send_announcement = {
          alias = "Send Announcement";
          sequence = singleton {
            parallel = (
              map (
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
                              # title = "Household Announcement";
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
              ) peopleList
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

    modules.services.hass = {
      smartLightingRooms = {
        joshuaRoom = {
          roomId = "joshua_room";
          roomDeviceId = "joshua_pixel_5";

          wakeUpLights = {
            enable = true;
            type = "alarm";
          };

          adaptiveLighting = {
            enable = true;
            sleepMode = {
              automate = true;
              disabledLights = [ "light.joshua_bulb_ceiling" ];
            };
          };

          automatedToggle = {
            enable = true;
            presenceTriggers = singleton {
              platform = "state";
              entity_id = "binary_sensor.ncase_m1_active";
              from = null;
            };

            presenceConditions = singleton {
              condition = "state";
              entity_id = "binary_sensor.ncase_m1_active";
              state = "on";
            };

            noPresenceConditions = singleton {
              condition = "state";
              entity_id = "binary_sensor.ncase_m1_active";
              state = "off";
            };
          };
        };

        lounge = {
          roomId = "lounge";
          adaptiveLighting = {
            enable = true;
            takeOverControl = true;
            minBrightness = 50;
          };
        };

        "${people.person1}Room" =
          let
            person = people.person1;
          in
          {
            roomId = "${person}_room";
            roomDeviceId = devices.${person}.name;

            wakeUpLights = {
              enable = true;
              type = "manual";
            };

            adaptiveLighting = {
              enable = true;
              sleepMode.automate = true;
            };
          };

        "${people.person2}Room" =
          let
            person = people.person2;
          in
          {
            roomId = "${person}_room";
            roomDeviceId = devices.${person}.name;

            wakeUpLights = {
              enable = true;
              type = "alarm";
            };

            adaptiveLighting = {
              enable = true;
              sleepMode.automate = true;
              sleepMode.color = [
                255
                0
                0
              ];
            };
          };

        "${people.person3}Room" =
          let
            person = people.person3;
          in
          {
            roomId = "${person}_room";
            roomDeviceId = devices.${person}.name;

            wakeUpLights = {
              enable = true;
              type = "alarm";
            };

            adaptiveLighting = {
              enable = true;
              sleepMode = {
                automate = true;
                disabledLights = [
                  "light.${person}_spot_ceiling_3"
                  "light.${person}_spot_ceiling_4"
                  "light.${person}_spot_ceiling_5"
                ];
              };
            };
          };
      };
    };
  };
}
