{
  lib,
  cfg,
  config,
  inputs,
}:
let
  inherit (lib)
    imap
    optional
    singleton
    splitString
    concatMapStringsSep
    toSentenceCase
    ;
  inherit (secrets.general) devices people;
  secrets = inputs.nix-resources.secrets.homeAssistant { inherit lib config; };

  formattedRoomName =
    room: (concatMapStringsSep " " (string: toSentenceCase string) (splitString "_" room));

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
      action = "notify.adults";
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
      action = "notify.mobile_app_${devices.${people.person4}.name}";
      data = {
        title = "Washing Machine Finished";
        message = "Take out the damp clothes";
      };
    };
  };

  # WARN: This requires a "Formula 1" calendar to be imported into hass.
  # Download an .ics file from f1calendar.com then create a calendar in hass
  # and add a random event it. This should create a
  # local_calendar.formula_1.ics in the hass .storage dir. Replace this file
  # with the downloaded ics.
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
          action = "notify.${person}";
          data = {
            title = "Formula 1 About to Start";
            message = "{{ state_attr('calendar.formula_1', 'message') }} in 15 mins!";
            data = {
              channel = "Formula 1";
              importance = "high";
              priority = "high";
              ttl = 0;
            };
          };
        };
      in
      [
        (mkNotify "joshua")
        (mkNotify people.person3)
        (mkNotify people.person5)
      ];
  };

  mowerErrorNotify = singleton {
    alias = "Automower Error Notify";
    mode = "single";
    trigger = [
      {
        platform = "state";
        entity_id = [ "sensor.lewis_error" ];
        from = null;
      }
    ];
    condition = [
      {
        condition = "template";
        value_template = "{{ has_value('sensor.lewis_error') }}";
      }
      {
        condition = "not";
        conditions = singleton {
          condition = "state";
          entity_id = "sensor.lewis_error";
          state = "no_error";
        };
      }
      {
        condition = "not";
        conditions = singleton {
          condition = "state";
          entity_id = "sensor.lewis_error";
          state = "sms_could_not_be_sent";
        };
      }
      {
        condition = "not";
        conditions = singleton {
          condition = "state";
          entity_id = "sensor.lewis_error";
          state = "low_battery";
        };
      }
    ];
    action = singleton {
      action = "notify.adults";
      data = {
        title = "Lewis Needs Help!";
        message = "{{ state_translated('sensor.lewis_error') }}";
        data = {
          channel = "Automower";
          ttl = 0;
          importance = "high";
          priority = "high";
        };
      };
    };
  };

  # When using hue wall switch modules with zigbee2mqtt they only send "toggle"
  # events to the lights. If a subset of the lights in a group are on this
  # makes it impossible to turn all lights off as it literally toggles them.
  hueWallSwitchForceOff =
    room: deviceId:
    singleton {
      alias = "${formattedRoomName room} Hue Wall Switch Force Off";
      mode = "single";
      triggers = singleton {
        trigger = "device";
        domain = "mqtt";
        device_id = deviceId;
        type = "action";
        subtype = "toggle";
      };
      actions = [
        {
          wait_for_trigger = singleton {
            trigger = "device";
            domain = "mqtt";
            device_id = deviceId;
            type = "action";
            subtype = "toggle";
          };
          timeout.seconds = 2;
          continue_on_timeout = false;
        }
        { delay.seconds = 1; }
        {
          action = "light.turn_off";
          target.entity_id = "light.${room}_lights";
        }
      ];
    };

  hueTapLightSwitch =
    room: deviceId:
    let
      inherit (cfg.rooms.${room}.lighting) adaptiveLighting;
    in
    singleton {
      alias = "${formattedRoomName room} Hue Tap Light Switch";
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
                action = "light.toggle";
                target.entity_id = "light.${room}_lights";
              })
              (singleton (
                if adaptiveLighting.enable then
                  {
                    action = "switch.toggle";
                    target.entity_id = "switch.adaptive_lighting_${room}_adaptive_lighting";
                  }
                else
                  {
                    action = "light.turn_on";
                    data.brightness_step_pct = 10;
                    data.transition = 2;
                  }
              ))
              (singleton (
                if adaptiveLighting.enable then
                  {
                    action = "switch.toggle";
                    target.entity_id = "switch.adaptive_lighting_sleep_mode_${room}_adaptive_lighting";
                  }
                else
                  {
                    action = "light.turn_on";
                    data.brightness_step_pct = -10;
                    data.transition = 2;
                  }
              ))
              (
                optional adaptiveLighting.enable {
                  action = "switch.turn_off";
                  target.entity_id = "switch.adaptive_lighting_${room}_adaptive_lighting";
                }
                ++ singleton {
                  action = "light.turn_on";
                  target.entity_id = "light.${room}_lights";
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
      alias = "${formattedRoomName room} Light Switch";
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
            (condition "on" { action = "light.turn_on"; })
            (condition "off" { action = "light.turn_off"; })
            (condition "brightness_up" {
              action = "light.turn_on";
              data.brightness_step_pct = 10;
              data.transition = 2;
            })
            (condition "brightness_down" {
              action = "light.turn_on";
              data.brightness_step_pct = -10;
              data.transition = 2;
            })
          ];
      };
    };

  # Fixes https://community.home-assistant.io/t/shelly-1-mqtt-always-unavailable-after-ha-restart/102827/32
  # The announce command doesn't seem useful as it just returns device info. I
  # think Shelly may have split the announce functionality into the
  # status_update command since this thread?
  shelliesStatusUpdate = singleton {
    alias = "Shellies Status Update";
    trigger = singleton {
      platform = "homeassistant";
      event = "start";
    };
    action = [
      { delay.seconds = 10; }
      {
        action = "mqtt.publish";
        data = {
          topic = "shellies/command";
          payload = "status_update";
        };
      }
    ];
  };
in
{
  services.home-assistant.config = {
    automation =
      binCollectionNotify
      ++ washingMachineNotify
      ++ formula1Notify
      ++ (hueLightSwitch "study" "49d9c39a26397a8a228ee484114aca0b")
      ++ (hueWallSwitchForceOff "lounge" "1e088cf4a7ed6be5c94d42e48f99fad2")
      # TODO: Need a new battery and a firmware update I think because the action names are different
      # ++ (hueLightSwitch "joshua_room" "ad126eeb4153cd333afe86a9553c06ef")
      ++ (hueTapLightSwitch "${people.person2}" "670ac1ecf423f069757c7ab30bec3142")
      ++ (hueTapLightSwitch "${people.person3}" "0097121e144203512aeacef37a03650c")
      ++ mowerErrorNotify
      ++ shelliesStatusUpdate;
  };
}
