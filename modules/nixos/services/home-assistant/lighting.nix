{
  ns,
  lib,
  config,
  ...
}:
let
  inherit (lib)
    types
    mkOption
    mkIf
    optional
    optionals
    all
    singleton
    mkMerge
    mapAttrsToList
    mkEnableOption
    ;
  cfg = config.${ns}.services.hass;
in
{
  options.${ns}.services.hass.rooms = mkOption {
    type = types.attrsOf (
      types.submodule (
        { name, config, ... }:
        {
          options.lighting = mkOption {
            description = ''
              Modular smart lighting functionality for the room. Also generates
              lovelace cards that can be added to the room's dashboard. Smart lighting
              features include: (1) adaptive lighting that changes lighting color and
              brightness to match the sun (in bedrooms, the adaptive lighting schedule
              is synced with the users wake-up and sleep-time determined from their
              next phone alarm and desired sleep duration configured in the dashboard),
              (2) wake-up lighting that automatically turns on the lights 1 hour before
              wake-up time and gradually increases brightness, (3) automated lighting
              toggle based on presence in the room and the natural outdoor brightness
              (inferred from solar power generation), and (4), automated sleep mode
              that dims the brightness and optionally turns off certain lights when the
              user's phone is placed on charge around sleep time.
            '';
            default = { };
            type = types.submodule {
              options = {
                enable = mkEnableOption "smart lighting integration";
                basicLights = mkEnableOption "basic lights that don't support warmth" // {
                  default = false;
                };

                individualLights = mkOption {
                  type = with types; listOf str;
                  default = [ ];
                  description = ''
                    Entity IDs of each individual light in the room. Will be
                    added as buttons to the dashboard if floor plan is
                    disabled.
                  '';
                };

                floorPlan = {
                  enable = mkEnableOption "floor plan lighting card";

                  camera = mkOption {
                    type = types.str;
                    default = "${name}_floorplan";
                    description = "Name of the home assistant camera entity that contains the floorplan";
                  };

                  mkFloorPlanLight = mkOption {
                    type = with types; functionTo (functionTo (functionTo attrs));
                    readOnly = true;
                    default = name: leftPos: topPos: {
                      inherit name leftPos topPos;
                    };
                  };

                  lights = mkOption {
                    description = "List of lights to create buttons for above the floorplan";
                    type = types.listOf (
                      types.submodule {
                        options = {
                          name = mkOption {
                            type = types.str;
                            example = "lounge_spot_ceiling_1";
                            description = "Light entity ID";
                          };

                          leftPos = mkOption {
                            type = types.int;
                          };

                          topPos = mkOption {
                            type = types.int;
                          };
                        };
                      }
                    );
                  };
                };

                wakeUpLights.enable = mkEnableOption ''
                  automatically turning on the lights 1 hour before the
                  alarm/wake-up time. Wake-up time will use the device's
                  next alarm if sleepTracking.useAlarm is enabled for the
                  room.
                '';

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
                    default = [ ];
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
                    default = [ ];
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
                    default = [ ];
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
              };
            };
          };

          config.lovelace.sections = singleton {
            title = "Lighting";
            priority = 1;
            type = "grid";
            cards =
              let
                inherit (config.lighting)
                  floorPlan
                  individualLights
                  adaptiveLighting
                  wakeUpLights
                  basicLights
                  ;
              in
              [
                {
                  type = "button";
                  name = "Toggle";
                  entity = "light.${name}_lights";
                  tap_action.action = "toggle";
                  layout_options = {
                    grid_columns = 1;
                    grid_rows = if basicLights then 2 else 3;
                  };
                }
                {
                  type = "tile";
                  entity = "light.${name}_lights";
                  name = "All Lights";
                  layout_options = {
                    grid_columns = 3;
                    grid_rows = if basicLights then 2 else 3;
                  };
                  features = [
                    { type = "light-brightness"; }
                  ] ++ optional (!basicLights) { type = "light-color-temp"; };
                }
              ]
              ++ (
                if floorPlan.enable then
                  singleton {
                    camera_image = "camera.${floorPlan.camera}";
                    type = "picture-elements";
                    elements = map (light: {
                      entity = "light.${light.name}";
                      tap_action.action = "toggle";
                      type = "state-icon";
                      style = {
                        background = "rgba(0, 0, 0, 0.8)";
                        border-radius = "50%";
                        left = "${toString light.leftPos}%";
                        top = "${toString light.topPos}%";
                      };
                    }) floorPlan.lights;
                  }
                else
                  (map (light: {
                    type = "tile";
                    entity = "light.${light}";
                    tap_action.action = "toggle";
                    visibility = singleton {
                      condition = "state";
                      entity = "light.${light}";
                      state_not = "unavailable";
                    };
                  }) individualLights)
              )
              ++ optionals adaptiveLighting.enable [
                {
                  name = "Adaptive Lighting";
                  type = "tile";
                  entity = "switch.adaptive_lighting_${name}";
                  tap_action.action = "toggle";
                  layout_options = {
                    grid_columns = 4;
                    grid_rows = 1;
                  };
                }
                {
                  name = "Sleep Mode";
                  type = "tile";
                  entity = "switch.adaptive_lighting_sleep_mode_${name}";
                  tap_action.action = "toggle";
                  layout_options = {
                    grid_columns = if (!wakeUpLights.enable) then 4 else 2;
                    grid_rows = 1;
                  };
                }
              ]
              ++ optional wakeUpLights.enable {
                name = "Wake Up Lights";
                type = "tile";
                entity = "input_boolean.${name}_wake_up_lights";
                tap_action.action = "toggle";
                layout_options = {
                  grid_columns = if (!adaptiveLighting.enable) then 4 else 2;
                  grid_rows = 1;
                };
              };
          };
        }
      )
    );
  };

  config = mkIf cfg.enableInternal {
    assertions = lib.${ns}.asserts [
      (all (x: x == true) (
        mapAttrsToList (
          _: roomCfg: roomCfg.lighting.wakeUpLights.enable -> roomCfg.sleepTracking.enable
        ) cfg.rooms
      ))
      "Home Assistant wake up lights require sleep tracking to be enabled"
    ];

    services.home-assistant.config = mkMerge (
      mapAttrsToList (
        roomId: roomCfg:
        let
          inherit (roomCfg) formattedRoomName;
          inherit (roomCfg.sleepTracking)
            useAlarm
            wakeUpTimestamp
            sleepTimestamp
            sleepDuration
            ;
          cfg' = roomCfg.lighting;
        in
        mkIf cfg'.enable (mkMerge [
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
                  entity_id = "input_boolean.${roomId}_wake_up_lights";
                  state = "on";
                };
                action = singleton {
                  action = "light.turn_on";
                  target.entity_id = "light.${roomId}_lights";
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
                      entity_id = [ "input_number.${roomId}_sleep_duration" ];
                      from = null;
                    }
                  ]
                  ++ (
                    if (!useAlarm) then
                      singleton {
                        platform = "state";
                        entity_id = [ "input_datetime.${roomId}_wake_up_time" ];
                        from = null;
                      }
                    else
                      [
                        {
                          platform = "state";
                          entity_id = [ "sensor.${roomCfg.deviceId}_next_alarm" ];
                          from = null;
                        }
                        {
                          platform = "state";
                          entity_id = [ "sensor.${roomCfg.deviceId}_next_alarm" ];
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
                        entity_id = "input_number.${roomId}_sleep_duration";
                        state = "unavailable";
                      }
                      ++ singleton (
                        if useAlarm then
                          {
                            condition = "state";
                            entity_id = "sensor.${roomCfg.deviceId}_next_alarm";
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
                            entity_id = "input_datetime.${roomId}_wake_up_time";
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
                            entity_id = "switch.adaptive_lighting_${roomId}";
                            use_defaults = "current";
                            sunrise_time = "{{ ${wakeUpTimestamp} | timestamp_custom('%H:%M:%S') }}";
                            # Set sunset 1.5 hours before sleep time so that lights
                            # will reach minimum brightness at sleep time
                            sunset_time = "{{ (${sleepTimestamp} - 1.5*60*60) | timestamp_custom('%H:%M:%S') }}";
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
                            entity_id = "switch.adaptive_lighting_${roomId}";
                            use_defaults = "configuration";
                          };
                        };
                      }
                    ];
                  };
              };

            input_boolean."${roomId}_wake_up_lights" = {
              name = "${formattedRoomName} Wake Up Lights";
              icon = "mdi:weather-sunset-up";
            };
          })

          (mkIf cfg'.adaptiveLighting.enable {
            adaptive_lighting = singleton {
              name = "${formattedRoomName} ";
              lights =
                if cfg'.adaptiveLighting.lights == null then
                  [ "light.${roomId}_lights" ]
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
                    entity_id = [ "switch.adaptive_lighting_sleep_mode_${roomId}" ];
                    from = null;
                  }
                  {
                    platform = "state";
                    entity_id = [ "light.${roomId}_lights" ];
                    to = "on";
                    id = "lights_on";
                  }
                ];
                condition = singleton {
                  condition = "state";
                  entity_id = "switch.adaptive_lighting_${roomId}";
                  state = "on";
                };
                action = [
                  { delay.seconds = 2; }
                  {
                    choose = [
                      {
                        conditions = singleton {
                          condition = "state";
                          entity_id = "switch.adaptive_lighting_sleep_mode_${roomId}";
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
                              entity_id = "switch.adaptive_lighting_sleep_mode_${roomId}";
                              state = "off";
                            }
                            {
                              condition = "state";
                              entity_id = "light.${roomId}_lights";
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
                      entity_id = [ "binary_sensor.${roomCfg.deviceId}_is_charging" ];
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
                      value_template = "{{ (now().timestamp() - 60*60) | round(0) == ${sleepTimestamp} }}";
                    }
                    {
                      platform = "state";
                      entity_id = [ "input_number.${roomId}_sleep_duration" ];
                      from = null;
                    }
                  ]
                  ++ singleton (
                    if useAlarm then
                      {
                        platform = "state";
                        entity_id = [ "sensor.${roomCfg.deviceId}_next_alarm" ];
                        from = null;
                      }
                    else
                      {
                        platform = "state";
                        entity_id = [ "input_datetime.${roomId}_wake_up_time" ];
                        from = null;
                      }
                  );
                condition = singleton {
                  condition = "state";
                  entity_id = "switch.adaptive_lighting_${roomId}";
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
                          target.entity_id = "switch.adaptive_lighting_sleep_mode_${roomId}";
                        };
                      }
                      {
                        conditions = singleton {
                          condition = "template";
                          value_template = "{{ (${wakeUpTimestamp} == 0) or (${timeToWake} > ((${sleepDuration} + 0.5)*60*60) + 60) or (${timeToWake} <= 61*60) }}";
                        };
                        sequence = singleton {
                          action = "switch.turn_off";
                          target.entity_id = "switch.adaptive_lighting_sleep_mode_${roomId}";
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
                entity_id = "sensor.${roomCfg.deviceId}_sleep_confidence";
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
                        entity_id = "light.${roomId}_lights";
                        state = "off";
                      }
                      (solarCondition true)
                    ] ++ cfg'.automatedToggle.presenceConditions;
                  };
                  "then" = singleton {
                    action = "light.turn_on";
                    target.entity_id = "light.${roomId}_lights";
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
                            entity_id = "light.${roomId}_lights";
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
                        target.entity_id = "light.${roomId}_lights";
                      };
                    }
                  ];
                };
            };
          })
        ])
      ) cfg.rooms
    );
  };
}
