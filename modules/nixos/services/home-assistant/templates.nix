# https://jinja.palletsprojects.com/en/3.1.x/templates/
{ lib, config }:
let
  inherit (lib)
    ns
    mkIf
    attrNames
    singleton
    ;
  cameras = attrNames config.services.frigate.settings.cameras;
in
{
  services.home-assistant.config = {
    recorder.exclude.entities = [ "sensor.powerwall_battery_remaining_time" ];

    # Do not use unique_id as it makes the config stateful and won't
    # necessarily remove sensors if they're removed from the config
    template = [
      {
        binary_sensor = [
          {
            name = "Powerwall Grid Charge Status";
            icon = "mdi:home-export-outline";
            state = "{{ states('sensor.powerwall_site_power') | float(0) < -0.1 }}";
            device_class = "battery_charging";
          }
          {
            name = "Powerwall Battery Charge Status";
            icon = "mdi:battery-charging";
            state = "{{ states('sensor.powerwall_battery_power') | float(0) < -0.1 }}";
            device_class = "battery_charging";
          }
          {
            name = "Washing Machine Running";
            icon = "mdi:washing-machine";
            state = "{{ states('sensor.washing_machine_status') == 'running' }}";
            device_class = "running";
          }
          {
            name = "Dishwasher Running";
            icon = "mdi:dishwasher";
            state = "{{ states('sensor.dishwasher_status') == 'running' }}";
            device_class = "running";
          }
        ]
        ++ map (camera: {
          name = "${lib.${ns}.upperFirstChar camera} Person Recently Updated";
          icon = "mdi:walk";
          state = "{{ (now().timestamp() - as_timestamp(states('image.${camera}_person'), default = 0)) < 5*60 }}";
          device_class = "update";
        }) cameras;

        sensor = [
          {
            name = "Powerwall Battery Remaining Time";
            icon = "mdi:battery-clock-outline";
            state = ''
              {% set power = states('sensor.powerwall_battery_power') | float(0) %}
              {% set remaining = states('sensor.powerwall_gateway_battery_remaining') | float(0) %}
              {% set capacity = states('sensor.powerwall_gateway_battery_capacity') | float(0) %}

              {% if power > 0.1 %}
                {% set remaining_mins = ((remaining / power) * 60) | round(0) %}
                {% set message = "until empty" %}
              {% elif power < -0.1 %}
                {% set remaining_mins = (((capacity - remaining) / (power * -1)) * 60) | round(0) %}
                {% set message = "until fully charged" %}
              {% endif %}

              {% if remaining_mins is not defined %}
                Battery inactive
              {% elif remaining_mins >= 60 %}
                {{ "%d hour%s %d minute%s %s" % (remaining_mins//60, ('s',''')[remaining_mins//60==1], remaining_mins%60, ('s',''')[remaining_mins%60==1], message) }}
              {% else %}
                {{ "%d minute%s %s" % (remaining_mins, ('s',''')[remaining_mins==1], message) }}
              {% endif %}
            '';
          }
          {
            name = "Powerwall Battery Percentage";
            icon = "mdi:home-battery";
            state = "{{ ((states('sensor.powerwall_gateway_battery_remaining') | float(0) / states('sensor.powerwall_gateway_battery_capacity') | float(1)) * 100) | int }}";
            unit_of_measurement = "%";
          }
          {
            name = "Powerwall Site Export Power";
            icon = "mdi:home-export-outline";
            state = "{{ [states('sensor.powerwall_site_power') | float(0) * -1, 0] | max }}";
            unit_of_measurement = "kW";
          }
          {
            name = "Lights On Count";
            icon = "mdi:lightbulb";
            state = "{{ states.light | rejectattr('attributes.entity_id', 'defined') | selectattr('state', 'eq', 'on') | list | count }}";
          }
          {
            name = "AC On Count";
            icon = "mdi:hvac";
            state = ''
              {{
                states.climate
                | selectattr('entity_id', 'contains', 'ac_room_temperature')
                | rejectattr ( 'state' , 'eq' , 'unavailable' )
                | rejectattr ( 'state' , 'eq' , 'off' )
                | list
                | count
              }}
            '';
          }
          {
            name = "Powerwall Aggregate Cost";
            icon = "mdi:currency-gbp";
            state = "{{ states('sensor.powerwall_site_import_cost') | float(0) - states('sensor.powerwall_site_export_compensation') | float(0) }}";
            unit_of_measurement = "GBP";
            state_class = "total";
          }
          {
            name = "Days To Bin Collection";
            icon = "mdi:calendar";
            state = "{{ state_attr('sensor.next_bin_collection', 'daysTo') }}";
            unit_of_measurement = "d";
          }
        ];
      }
      {
        trigger = [
          {
            platform = "webhook";
            webhook_id = "ncase-m1-active";
          }
          {
            platform = "homeassistant";
            event = "start";
          }
        ];
        binary_sensor = {
          name = "NCASE-M1 Active";
          unique_id = "ncase_m1_active";
          icon = "mdi:desktop-classic";
          state = ''
            {% if trigger.platform == 'webhook' %}
              {{ trigger.json.active }}
            {% else %}
              'off'
            {% endif %}
          '';
          auto_off = 70; # heartbeat sent every 60 seconds
        };
      }
      (
        let
          threshold = 10;
          triggers =
            (map
              (enable: {
                platform = "numeric_state";
                entity_id = [ "sensor.joshua_presence_illuminance" ];
                above = mkIf enable threshold;
                below = mkIf (!enable) threshold;
                for.minutes = 10;
              })
              [
                true
                false
              ]
            )
            ++ singleton {
              platform = "homeassistant";
              event = "start";
            };
        in
        {
          trigger = triggers;
          binary_sensor = {
            name = "Joshua Dark Mode Brightness Threshold";
            icon = "mdi:white-balance-sunny";
            device_class = "light";
            state = "{{ (states('sensor.joshua_presence_illuminance') | float) > ${toString threshold} }}";
          };
        }
      )
    ];

    sensor = [
      {
        name = "Smoothed Solar Power";
        platform = "filter";
        entity_id = "sensor.powerwall_solar_power";
        filters = singleton {
          # The solar power sensor updates every 30 secs
          filter = "time_simple_moving_average";
          window_size = "00:05";
          precision = 2;
        };
      }
      # WARN: I don't declaratively configure the waste collection integration
      # because it contains my address and I don't want that on github.
      # Unfortunately the main integration must also be configured in yaml for
      # the sensor to be. Copy this sensor config into the setup GUI:
      # {
      #   name = "Next Bin Collection";
      #   platform = "waste_collection_schedule";
      #   details_format = "upcoming";
      #   leadtime = 2;
      #   value_template = "{{ value.types|join(', ') }} {% if value.daysTo == 0 %}today{% elif value.daysTo == 1 %}tomorrow{% else %}in {{ value.daysTo }} days{% endif %}";
      #   date_template = "{{ value.date.strftime('%a, %d.%m.%Y') }}";
      #   add_days_to = true;
      # }
      # This one is for the notification automation
      # {
      #   name = "Bin Collection Types";
      #   platform = "waste_collection_schedule";
      #   details_format = "hidden";
      #   leadtime = 1;
      #   value_template = "{{ value.types|join(', ') }}";
      #   add_days_to = true;
      # }
    ];

    thermal_comfort = singleton {
      custom_icons = true;
      sensor = [
        # The unique IDs here are random and have no meaning
        {
          name = "Outdoor Thermal Comfort";
          temperature_sensor = "sensor.outdoor_sensor_temperature";
          humidity_sensor = "sensor.outdoor_sensor_humidity";
          sensor_types = [
            "frost_risk"
            "heat_index"
          ];
          unique_id = "63eaf56b-9edf-42c7-83c7-cbab6f16fec4";
        }
      ];
    };
  };
}
