{
  lib,
  config,
  inputs,
  ...
}:
let
  inherit (lib)
    mkIf
    utils
    head
    optional
    optionals
    attrNames
    attrValues
    singleton
    splitString
    concatMapStringsSep
    ;
  inherit (secrets.general) devices people;
  inherit (inputs.nix-resources.secrets) fqDomain;
  inherit (config.modules.services) frigate;
  cfg = config.modules.services.hass;
  cameras = attrNames config.services.frigate.settings.cameras;
  secrets = inputs.nix-resources.secrets.hass { inherit lib config; };

  formattedRoomName =
    room: (concatMapStringsSep " " (string: utils.upperFirstChar string) (splitString "_" room));

  frigateEntranceNotify = singleton {
    alias = "Entrance Person Notify";
    use_blueprint = {
      path = "SgtBatten/frigate_notifications.yaml";
      input = {
        camera = "camera.driveway";
        state_filter = true;
        state_entity = "input_boolean.high_alert_surveillance";
        state_filter_states = [ "off" ];
        notify_device = (head (attrValues devices)).id;
        notify_group = "All Notify Devices";
        base_url = "https://home.${fqDomain}";
        group = "frigate-entrance-notification";
        title = "Security Alert";
        message = "A {{ label }} {{ 'is loitering' if loitering else 'was detected' }} in the entrance";
        update_thumbnail = true;
        alert_once = true;
        zone_filter = true;
        zones = [ "entrance" ];
      };
    };
  };

  frigateCatNotify = map (camera: {
    alias = "${utils.upperFirstChar camera} Cat Notify";
    use_blueprint = {
      path = "SgtBatten/frigate_notifications.yaml";
      input = {
        camera = "camera.${camera}";
        notify_device = (head (attrValues devices)).id;
        notify_group = "All Notify Devices";
        sticky = true;
        group = "frigate-cat-notification";
        base_url = "https://home.${fqDomain}";
        ios_live_view = "camera.${camera}";
        title = "Cat Detected";
        mess = "A cat {{ 'is loitering' if loitering else 'was detected' }} on the {{ camera_name }} camera";
        color = "#f44336";
        update_thumbnail = true;
        labels = [ "cat" ];
      };
    };
  }) cameras;

  frigateHighAlertNotify = map (camera: {
    alias = "High Alert ${utils.upperFirstChar camera} Notify";
    use_blueprint = {
      path = "SgtBatten/frigate_notifications.yaml";
      input = {
        camera = "camera.${camera}";
        state_filter = true;
        state_entity = "input_boolean.high_alert_surveillance";
        state_filter_states = [ "on" ];
        notify_device = (head (attrValues devices)).id;
        notify_group = "All Notify Devices";
        sticky = true;
        group = "frigate-notification";
        base_url = "https://home.${fqDomain}";
        title = "Security Alert";
        ios_live_view = "camera.${camera}";
        message = "A {{ label }} {{ 'is loitering' if loitering else 'was detected' }} on the {{ camera_name }} camera";
        color = "#f44336";
        update_thumbnail = true;
      };
    };
  }) cameras;

  heatingTimeToggle =
    map
      (
        enable:
        let
          stringMode = if enable then "enable" else "disable";
          oppositeMode = if enable then "disable" else "enable";
        in
        {
          alias = "Heating ${if enable then "Enable" else "Disable"}";
          mode = "single";
          trigger = [
            {
              platform = "homeassistant";
              event = "start";
            }
            {
              platform = "time";
              at = "input_datetime.heating_${stringMode}_time";
            }
          ];
          condition =
            let
              timeCond = {
                condition = "time";
                after = "input_datetime.heating_${stringMode}_time";
                before = "input_datetime.heating_${oppositeMode}_time";
              };
            in
            optional (!enable) timeCond
            ++ optional enable {
              condition = "and";
              conditions = [
                timeCond
                {
                  condition = "state";
                  entity_id = "input_boolean.heating_enabled";
                  state = "on";
                }
              ];
            };
          action = singleton {
            service = "climate.set_hvac_mode";
            metadata = { };
            data = {
              hvac_mode = if enable then "heat" else "off";
            };
            target.entity_id = [
              "climate.joshua_thermostat"
              "climate.hallway"
            ];
          };
        }
      )
      [
        true
        false
      ];

  joshuaDehumidifierTankFull = singleton {
    alias = "Joshua Dehumidifier Full Notify";
    mode = "single";
    trigger = singleton {
      platform = "state";
      entity_id = "sensor.joshua_dehumidifier_tank_status";
      to = "Full";
      for.minutes = 1;
    };
    action = singleton {
      service = "notify.mobile_app_joshua_pixel_5";
      data = {
        title = "Dehumidifier";
        message = "Tank full";
      };
    };
  };

  joshuaDehumidifierToggle =
    map
      (enable: {
        alias = "Joshua Dehumidifier ${if enable then "Enable" else "Disable"}";
        mode = "single";
        trigger = singleton {
          platform = "numeric_state";
          entity_id = [ "sensor.joshua_mold_indicator" ];
          above = mkIf enable 73;
          below = mkIf (!enable) 67;
          for.minutes = if enable then 0 else 30;
        };
        condition = singleton {
          condition = "state";
          entity_id = "input_boolean.joshua_dehumidifier_automatic_control";
          state = "on";
        };
        action = singleton {
          service = "switch.turn_${if enable then "on" else "off"}";
          target.entity_id = "switch.joshua_dehumidifier";
        };
      })
      [
        true
        false
      ];

  joshuaLightsToggle =
    map
      (enable: {
        alias = "Joshua Lights ${if enable then "On" else "Off"}";
        mode = "single";
        trigger =
          [
            {
              platform = "numeric_state";
              entity_id = [ "sensor.smoothed_solar_power" ];
              above = mkIf (!enable) 2;
              below = mkIf enable 2;
              id = "Brightness";
            }
            {
              platform = "state";
              entity_id = [ "binary_sensor.ncase_m1_active" ];
              from = if enable then "off" else "on";
              to = if enable then "on" else "off";
              for.seconds = if enable then 0 else 30;
            }
          ]
          ++ optional enable {
            platform = "template";
            value_template = "{{ now().timestamp() | round(0) == (${joshuaWakeUpTimestamp} - 60*60) }}";
            id = "Wake Up Time";
          };
        condition =
          let
            mainCondition = {
              condition = if enable then "and" else "or";
              conditions = [
                {
                  condition = "numeric_state";
                  entity_id = "sensor.smoothed_solar_power";
                  above = mkIf (!enable) 2;
                  below = mkIf enable 2;
                }
                {
                  condition = "state";
                  entity_id = "binary_sensor.ncase_m1_active";
                  state = if enable then "on" else "off";
                }
              ];
            };
            wakeUpCondition = {
              condition = "or";
              conditions = [
                mainCondition
                {
                  condition = "and";
                  conditions = [
                    {
                      condition = "trigger";
                      id = "Wake Up Time";
                    }
                    {
                      condition = "state";
                      entity_id = "input_boolean.joshua_room_wake_up_lights";
                      state = "on";
                    }
                  ];
                }
              ];
            };
          in
          optional (!enable) mainCondition ++ optional enable wakeUpCondition;
        action =
          let
            lightService = {
              service = "light.turn_${if enable then "on" else "off"}";
              target.entity_id = "light.joshua_room_lights";
            };
          in
          optional enable lightService
          ++ optional (!enable) {
            "if" = [
              {
                condition = "not";
                conditions = [
                  {
                    condition = "and";
                    conditions = [
                      {
                        condition = "trigger";
                        id = [ "Brightness" ];
                      }
                      {
                        condition = "numeric_state";
                        entity_id = "sensor.joshua_pixel_5_sleep_confidence";
                        above = 90;
                      }
                    ];
                  }
                ];
              }
            ];
            "then" = [ lightService ];
          };
      })
      [
        true
        false
      ];

  joshuaWakeUpTimestamp = "(as_timestamp(states('sensor.joshua_pixel_5_next_alarm'), default = 0) | round(0))";

  joshuaAdaptiveLightingSunTimes = [
    {
      alias = "Joshua Room Lighting Sun Times";
      mode = "single";
      trigger = [
        {
          platform = "state";
          entity_id = [ "sensor.joshua_pixel_5_next_alarm" ];
        }
        {
          platform = "homeassistant";
          event = "start";
        }
      ];
      action = [
        {
          "if" = [
            {
              condition = "template";
              value_template = "{{ has_value('sensor.joshua_pixel_5_next_alarm') }}";
            }
          ];
          "then" = [
            {
              service = "adaptive_lighting.change_switch_settings";
              data = {
                use_defaults = "configuration";
                entity_id = "switch.adaptive_lighting_joshua_room";
                sunrise_time = "{{ ${joshuaWakeUpTimestamp} | timestamp_custom('%H:%M:%S') }}";
                # Set sunset 1 hour before sleep time so that lights will reach
                # minimum brightness 30 mins before sleep time. Sleep mode enables 30
                # mins before sleep time.
                sunset_time = "{{ (${joshuaWakeUpTimestamp} - 9*60*60) | timestamp_custom('%H:%M:%S') }}";
              };
            }
          ];
          "else" = [
            {
              service = "adaptive_lighting.change_switch_settings";
              data = {
                entity_id = "switch.adaptive_lighting_joshua_room";
                use_default = "configuration";
              };
            }
          ];
        }
      ];
    }
  ];

  joshuaSleepModeToggle =
    map
      (enable: {
        alias = "Joshua Room Sleep Mode ${if enable then "Enable" else "Disable"}";
        mode = "single";
        trigger =
          [
            {
              platform = "state";
              entity_id = [ "sensor.joshua_pixel_5_next_alarm" ];
            }
            {
              platform = "template";
              value_template =
                if enable then
                  "{{ now().timestamp() | round(0) == (${joshuaWakeUpTimestamp} - 8.5*60*60) }}"
                else
                  "{{ now().timestamp() | round(0) == (${joshuaWakeUpTimestamp} - 60*60) }}";
            }
            {
              platform = "state";
              entity_id = [ "binary_sensor.ncase_m1_active" ];
              from = if enable then "on" else "off";
              to = if enable then "off" else "on";
            }
            {
              platform = "homeassistant";
              event = "start";
            }
          ]
          ++ optional enable {
            platform = "state";
            entity_id = [ "light.joshua_room_lights" ];
            to = "on";
          };
        condition =
          [
            {
              condition = "template";
              value_template = ''
                {% set time_to_wake = ${joshuaWakeUpTimestamp} - (now().timestamp() | round(0)) %}
                {{ (${joshuaWakeUpTimestamp} != 0) and ${
                  if enable then
                    "(time_to_wake <= 8.5*60*60) and (time_to_wake > 60*60)"
                  else
                    "((time_to_wake <= 60*60) or (time_to_wake > 8.5*60*60))"
                } }}
              '';
            }
          ]
          ++ optional enable {
            condition = "state";
            entity_id = "binary_sensor.ncase_m1_active";
            state = "off";
          };
        action =
          [
            {
              service = "switch.turn_${if enable then "on" else "off"}";
              target.entity_id = "switch.adaptive_lighting_sleep_mode_joshua_room";
            }
          ]
          ++ optionals enable [
            # Delay to wait for 1 second adaptive lighting transition as turning
            # off lights during transition doesn't work
            { delay.seconds = 2; }
            {
              service = "light.turn_off";
              target.entity_id = "light.joshua_bulb_ceiling";
            }
          ]
          ++ optional (!enable) {
            "if" = singleton {
              condition = "state";
              entity_id = "light.joshua_room_lights";
              state = "on";
            };
            "then" = [
              { delay.seconds = 2; }
              {
                service = "light.turn_on";
                target.entity_id = "light.joshua_bulb_ceiling";
              }
            ];
          };
      })
      [
        true
        false
      ];

  binCollectionNotify = singleton {
    alias = "Bin Collection Notify";
    mode = "single";
    trigger = singleton {
      platform = "time";
      at = "19:00:00";
    };
    condition = singleton {
      condition = "template";
      value_template = "{{ is_state_attr('sensor.bin_collection_types', 'daysTo', 1) }}";
    };
    action = singleton {
      service = "notify.adult_notify_devices";
      data = {
        title = "Bin Collection Tomorrow";
        message = "{{ states('sensor.bin_collection_types') }}";
      };
    };
  };

  washingMachineNotify = singleton {
    alias = "Washing Machine Notify";
    mode = "single";
    trigger = singleton {
      platform = "state";
      entity_id = [ "sensor.washing_machine_status" ];
      from = "running";
      to = "program_ended";
    };
    condition = singleton {
      condition = "time";
      after = "07:00:00";
      before = "22:00:00";
    };
    action = singleton {
      service = "notify.mobile_app_${people.person4}_iphone";
      data = {
        title = "Washing Machine Finished";
        message = "Take out the damp clothes";
      };
    };
  };

  formula1Notify = singleton {
    alias = "Formula 1 Notify";
    mode = "single";
    trigger = singleton {
      platform = "template";
      value_template = "{{ now.timestamp() | round(0) == (as_timestamp(state_attr('calendar.formula_1', 'start_time'), default = 0) | round(0) - 15*60) }}";
    };
    condition = singleton {
      condition = "time";
      after = "07:00:00";
      before = "00:00:00";
    };
    action =
      let
        mkNotify = device: {
          service = "notify.mobile_app_${device}";
          data = {
            title = "Formula 1 About to Start";
            message = "{{ state_attr('calendar.formula_1', 'message') }} in 15 mins!";
          };
        };
      in
      [ (mkNotify "joshua_pixel_5") ];
  };

  lightsAvailabilityNotify = map (data: {
    alias = (formattedRoomName data.room) + " Ceiling Lights Availability Notify";
    mode = "single";
    trigger = singleton {
      platform = "state";
      entity_id = [ "light.${data.light}" ];
      to = "unavailable";
    };
    action = singleton {
      service = "notify.mobile_app_joshua_pixel_5";
      data = {
        title = "${formattedRoomName data.room} Lights Became Unavailable";
        message = "Turn the switch back on";
      };
    };
  }) cfg.ceilingLightRooms;

  room2LightsToggle =
    let
      room = "${people.person2}_room";
    in
    singleton {
      alias = (formattedRoomName room) + " Light Switch";
      mode = "single";
      trigger = singleton {
        platform = "device";
        domain = "mqtt";
        device_id = "670ac1ecf423f069757c7ab30bec3142";
        type = "action";
        subtype = "press_1";
      };
      action = singleton {
        service = "light.toggle";
        target.entity_id = "light.${room}_lights";
      };
    };

  hueLightSwitch =
    room: deviceId:
    singleton {
      alias = "${utils.upperFirstChar room} Light Switch";
      mode = "single";
      trigger =
        let
          buttonTrigger = button: id: {
            inherit id;
            platform = "device";
            domain = "mqtt";
            device_id = deviceId;
            type = "action";
            subtype = button;
          };
        in
        [
          (buttonTrigger "on_press_release" "on")
          (buttonTrigger "off_press_release" "off")
          (buttonTrigger "up_press_release" "brightness_up")
          (buttonTrigger "down_press_release" "brightness_down")
        ];
      action = singleton {
        choose =
          let
            condition = trigger: action: {
              conditions = singleton {
                condition = "trigger";
                id = [ trigger ];
              };
              sequence = [ (action // { target.entity_id = "light.${room}_lights"; }) ];
            };
          in
          [
            (condition "on" { service = "light.turn_on"; })
            (condition "off" { service = "light.turn_off"; })
            (condition "brightness_up" {
              service = "light.turn_on";
              data.brightness_step_pct = 10;
              data.transition = 2;
            })
            (condition "brightness_down" {
              service = "light.turn_on";
              data.brightness_step_pct = -10;
              data.transition = 2;
            })
          ];
      };
    };
in
mkIf cfg.enableInternal {
  services.home-assistant.config = {
    automation =
      heatingTimeToggle
      ++ joshuaDehumidifierToggle
      ++ joshuaDehumidifierTankFull
      ++ joshuaLightsToggle
      ++ joshuaAdaptiveLightingSunTimes
      ++ joshuaSleepModeToggle
      ++ binCollectionNotify
      ++ washingMachineNotify
      ++ formula1Notify
      ++ lightsAvailabilityNotify
      ++ room2LightsToggle
      ++ (hueLightSwitch "lounge" "12a188fc9e93182d852924b602153741")
      ++ (hueLightSwitch "study" "49d9c39a26397a8a228ee484114aca0b")
      ++ optionals frigate.enable (frigateEntranceNotify ++ frigateCatNotify ++ frigateHighAlertNotify);

    input_datetime = {
      heating_disable_time = {
        name = "Heating Disable Time";
        has_time = true;
      };

      heating_enable_time = {
        name = "Heating Enable Time";
        has_time = true;
      };
    };

    input_boolean = {
      heating_enabled = {
        name = "Heating Enabled";
        icon = "mdi:heating-coil";
      };

      joshua_dehumidifier_automatic_control = {
        name = "Joshua Dehumidifier Automatic Control";
        icon = "mdi:air-humidifier";
      };

      high_alert_surveillance = {
        name = "High Alert Surveillance";
        icon = "mdi:cctv";
      };

      joshua_room_wake_up_lights = {
        name = "Joshua Room Wake Up Lights";
        icon = "mdi:weather-sunset-up";
      };
    };
  };
}
