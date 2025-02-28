{ lib }:
let
  inherit (lib) singleton;

  # The shelly should be configured with input mode "Switch", output type
  # "Detached" and a timer that turns off the input switch after 3 seconds. The
  # door responds to rising edge inputs.
  shellyId = "shellyplus1-e465b8b961a4";
  doorSeconds = 20;
in
{
  services.home-assistant.config = {
    mqtt = singleton {
      binary_sensor = {
        name = "Garage Door Closed";
        icon = "mdi:garage";
        payload_on = false;
        payload_off = true;
        qos = 1;
        state_topic = "${shellyId}/status/input:0";
        device_class = "garage_door";
        value_template = "{{ value_json.state }}";
        availability_topic = "${shellyId}/online";
        payload_available = "true";
        payload_not_available = "false";
      };
    };

    template = singleton {
      trigger = [
        {
          platform = "state";
          entity_id = [ "binary_sensor.garage_door_closed" ];
          from = "off";
          to = "on";
          id = "Opening";
        }
        {
          platform = "state";
          entity_id = [ "binary_sensor.garage_door_closed" ];
          from = null;
          to = "on";
          for.seconds = doorSeconds;
          id = "Open";
        }
        {
          platform = "state";
          entity_id = [ "binary_sensor.garage_door_closed" ];
          from = null;
          to = "off";
          id = "Closed";
        }
        {
          platform = "state";
          entity_id = [ "script.garage_door_toggle" ];
          from = "off";
          to = "on";
          id = "script_start";
        }
        {
          platform = "state";
          entity_id = [ "script.garage_door_toggle" ];
          from = "on";
          to = "off";
          id = "script_stop";
        }
        {
          platform = "state";
          entity_id = [ "binary_sensor.garage_door_closed" ];
          to = "unavailable";
          id = "unavailable";
        }
        {
          platform = "state";
          entity_id = [ "binary_sensor.garage_door_closed" ];
          to = "unknown";
          id = "unknown";
        }
      ];
      sensor = {
        name = "Garage Door Status";
        icon = "mdi:garage";
        state = ''
          {% if trigger.id == 'script_start' %}
            {% if is_state('binary_sensor.garage_door_closed', 'on') %}
              Closing
            {% else %}
              {{ states('sensor.garage_door_status') }}
            {% endif %}
          {% elif trigger.id == 'script_stop' %}
            {% if states('sensor.garage_door_status') == 'Closing' %}
              Jammed
            {% else %}
              {{ states('sensor.garage_door_status') }}
            {% endif %}
          {% else %}
            {{ trigger.id }}
          {% endif %}
        '';
      };
    };

    script.garage_door_toggle = {
      alias = "Garage Door Toggle";
      # By using mode single here we can ensure that the door will be given
      # time to open/close and not get interrupted
      mode = "single";
      sequence = [
        {
          action = "mqtt.publish";
          data = {
            qos = "1";
            retain = false;
            topic = "${shellyId}/command/switch:0";
            payload = "on";
          };
        }
        { delay.seconds = doorSeconds; }
      ];
    };

    automation = [
      {
        # For some reason the shelly goes into an unavailable or unknown state
        # after reloading yaml config. Sending status_update fixes it.
        alias = "Garage Shelly Update";
        mode = "single";
        trigger =
          map
            (state: {
              platform = "state";
              entity_id = [ "binary_sensor.garage_door_closed" ];
              from = null;
              to = state;
              for.minutes = 1;
            })
            [
              "unavailable"
              "unknown"
            ];
        action = singleton {
          action = "mqtt.publish";
          data = {
            topic = "${shellyId}/command";
            payload = "status_update";
          };
        };
      }
      {
        alias = "Garage Door Jammed Notify";
        mode = "single";
        trigger = singleton {
          platform = "state";
          entity_id = [ "sensor.garage_door_status" ];
          from = null;
          to = "Jammed";
        };
        action = singleton {
          action = "notify.adults";
          data = {
            title = "Garage Door Jammed";
            message = "Something is preventing the garage door from closing";
            data = {
              ttl = 0;
              importance = "high";
              priority = "high";
              channel = "Garage Door";
              tag = "garage-door-jammed";
              notification_icon = "mdi:garage-alert-variant";
            };
          };
        };
      }
      {
        alias = "Garage Door Close Notify Action";
        mode = "single";
        trigger = singleton {
          platform = "event";
          event_type = "mobile_app_notification_action";
          event_data.action = "CLOSE_GARAGE_DOOR";
        };
        condition = singleton {
          condition = "state";
          entity_id = "binary_sensor.garage_door_closed";
          state = "off";
        };
        action = singleton { action = "script.garage_door_toggle"; };
      }
      {
        alias = "Garage Door Open Notify";
        mode = "single";
        trigger = singleton {
          platform = "time_pattern";
          minutes = "30";
        };
        condition = [
          {
            condition = "sun";
            after = "sunset";
            before = "sunrise";
          }
          {
            condition = "state";
            entity_id = "binary_sensor.garage_door_closed";
            state = "on";
            for.minutes = 30;
          }
        ];
        action = singleton {
          action = "notify.adults";
          data = {
            title = "Garage Door Open";
            message = "Tap and hold to close it";
            data = {
              ttl = 0;
              importance = "high";
              priority = "high";
              channel = "Garage Door";
              tag = "garage-door-open";
              notification_icon = "mdi:garage-alert-variant";
              actions = singleton {
                action = "CLOSE_GARAGE_DOOR";
                title = "Close";
              };
            };
          };
        };
      }
    ];
  };
}
