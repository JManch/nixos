{ lib, config, ... }:
let
  cfg = config.modules.services.hass;
in
lib.mkIf (cfg.enableInternal)
{
  services.home-assistant.config = {
    recorder.exclude.entities = [ "sensor.powerwall_battery_remaining_time" ];

    # Do not use unique_id as it makes the config stateful and won't
    # necessarily remove sensors if they're removed from the config
    template = [{
      binary_sensor = [
        {
          name = "Powerwall Grid Charge Status";
          icon = "mdi:home-export-outline";
          state = "{{ (states('sensor.powerwall_site_power') | float) < -0.05 }}";
          device_class = "battery_charging";
        }
        {
          name = "Powerwall Battery Charge Status";
          icon = "mdi:battery-charging";
          state = "{{ (states('sensor.powerwall_battery_power') | float) < -0.05 }}";
          device_class = "battery_charging";
        }
        {
          name = "Washing Machine Running";
          state = "{{ states('sensor.washing_machine_status') == 'Running' }}";
          device_class = "running";
        }
        {
          name = "Dishwasher Running";
          state = "{{ states('sensor.dishwasher_status') == 'Running' }}";
          device_class = "running";
        }
      ];

      sensor = [
        {
          name = "Powerwall Battery Remaining Time";
          icon = "mdi:battery-clock-outline";
          state = ''
            {% set power = (states('sensor.powerwall_battery_power')|float) %}
            {% set remaining = (states('sensor.powerwall_gateway_battery_remaining')|float) %}
            {% set capacity = (states('sensor.powerwall_gateway_battery_capacity')|float) %}

            {% if power > 0.05 %}
              {% set remaining_mins = ((remaining / power) * 60) | round(0) %}
              {% set message = "until empty" %}
            {% elif power < -0.05 %}
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
          name = "Lights On Count";
          icon = "mdi:lightbulb";
          state = "{{ states.light | rejectattr('attributes.entity_id', 'defined') | selectattr('state', 'eq', 'on') | list | count }}";
        }
      ];
    }];
  };
}