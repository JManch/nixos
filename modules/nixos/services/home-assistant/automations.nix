{
  lib,
  config,
  inputs,
  ...
}:
let
  inherit (lib)
    mkIf
    imap
    utils
    optional
    optionals
    attrNames
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
        notify_device = devices.joshua.id;
        notify_group = "Adult Notify Devices";
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
        notify_device = devices.joshua.id;
        notify_group = "Adult Notify Devices";
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
        notify_device = devices.joshua.id;
        notify_group = "Adult Notify Devices";
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
              "climate.joshua_radiator_thermostat"
              "climate.hallway_radiator_thermostat"
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
      service = "notify.${devices.joshua.name}";
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
      service = "notify.${devices.${people.person4}.name}";
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
      value_template = "{{ now().timestamp() | round(0) == (as_timestamp(state_attr('calendar.formula_1', 'start_time'), default = 0) | round(0) - 15*60) }}";
    };
    condition = singleton {
      condition = "time";
      after = "07:00:00";
      before = "00:00:00";
    };
    action =
      let
        mkNotify = person: {
          service = "notify.${devices.${person}.name}";
          data = {
            title = "Formula 1 About to Start";
            message = "{{ state_attr('calendar.formula_1', 'message') }} in 15 mins!";
          };
        };
      in
      [ (mkNotify "joshua") ];
  };

  lightsAvailabilityNotify = map (data: {
    alias = (formattedRoomName data.room) + " Ceiling Lights Availability Notify";
    mode = "single";
    trigger = singleton {
      platform = "state";
      entity_id = [ "light.${data.light}" ];
      to = "unavailable";
      for.minutes = 1;
    };
    action = singleton {
      service = "notify.${devices.joshua.name}";
      data = {
        title = "${formattedRoomName data.room} Lights Became Unavailable";
        message = "Turn the switch back on";
      };
    };
  }) cfg.ceilingLightRooms;

  hueTapLightSwitch =
    room: deviceId:
    let
      smartLightingCfg = config.modules.services.hass.smartLightingRooms.${room};
      roomId = smartLightingCfg.roomId or room;
      hasAdaptiveLighting = smartLightingCfg.adaptiveLighting.enable or false;
    in
    singleton {
      alias = "${formattedRoomName roomId} Hue Tap Light Switch";
      mode = "single";
      trigger = map (button: {
        platform = "device";
        domain = "mqtt";
        device_id = deviceId;
        type = "action";
        subtype = "press_${toString button}";
        id = "press_${toString button}";
      }) (builtins.genList (x: x + 1) 4);
      action = singleton {
        choose =
          imap
            (button: sequence: {
              inherit sequence;
              conditions = singleton {
                condition = "trigger";
                id = [ "press_${toString button}" ];
              };
            })
            # Button 1: Toggle lights
            # Button 2: Toggle adaptive lighting or increase brightness
            # Button 3: Toggle adaptive lighting sleep mode or decrease brightness
            # Button 4: Set lights to max brightness
            [
              (singleton {
                service = "light.toggle";
                target.entity_id = "light.${roomId}_lights";
              })
              (singleton (
                if hasAdaptiveLighting then
                  {
                    service = "switch.toggle";
                    target.entity_id = "switch.adaptive_lighting_${roomId}";
                  }
                else
                  {
                    service = "light.turn_on";
                    data.brightness_step_pct = 10;
                    data.transition = 2;
                  }
              ))
              (singleton (
                if hasAdaptiveLighting then
                  {
                    service = "switch.toggle";
                    target.entity_id = "switch.adaptive_lighting_sleep_mode_${roomId}";
                  }
                else
                  {
                    service = "light.turn_on";
                    data.brightness_step_pct = -10;
                    data.transition = 2;
                  }
              ))
              (
                optional hasAdaptiveLighting {
                  service = "switch.turn_off";
                  target.entity_id = "switch.adaptive_lighting_${roomId}";
                }
                ++ singleton {
                  service = "light.turn_on";
                  target.entity_id = "light.${roomId}_lights";
                  data.brightness_pct = 100;
                  data.kelvin = 6500;
                }
              )
            ];
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
      ++ binCollectionNotify
      ++ washingMachineNotify
      ++ formula1Notify
      ++ lightsAvailabilityNotify
      ++ (hueLightSwitch "lounge" "12a188fc9e93182d852924b602153741")
      ++ (hueLightSwitch "study" "49d9c39a26397a8a228ee484114aca0b")
      ++ (hueTapLightSwitch "${people.person2}Room" "670ac1ecf423f069757c7ab30bec3142")
      ++ (hueTapLightSwitch "${people.person3}Room" "0097121e144203512aeacef37a03650c")
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
    };
  };
}
