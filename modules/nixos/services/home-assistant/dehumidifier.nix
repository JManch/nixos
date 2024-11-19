{
  ns,
  lib,
  config,
  ...
}:
let
  inherit (lib)
    mkIf
    types
    mkMerge
    mkOption
    mkEnableOption
    mapAttrsToList
    optional
    singleton
    ;
  cfg = config.${ns}.services.hass;
in
{
  options.${ns}.services.hass.rooms = mkOption {
    type = types.attrsOf (
      types.submodule (
        { name, config, ... }:
        {
          options.dehumidifier = {
            enable = mkEnableOption "smart dehumidifier";

            switchId = mkOption {
              type = types.str;
              example = "joshua_dehumidifier";
              description = "Entity ID of the dehumidifier switch";
            };

            powerId = mkOption {
              type = types.str;
              default = "${config.dehumidifier.switchId}_power";
              description = "Entity ID of the dehumidifier power usage";
            };

            calibrationFactor = mkOption {
              type = types.float;
              example = 1.754;
              description = ''
                Mold indicator calibration value. See
                https://www.home-assistant.io/integrations/mold_indicator/#calibration
              '';
            };

            thresholds = {
              upper = mkOption {
                type = types.int;
                default = 85;
                description = "Mold indicator value that will enable the dehumifier";
              };

              lower = mkOption {
                type = types.int;
                default = 78;
                description = "Mold indicator value that will disable the dehumifier";
              };
            };

          };

          config.lovelace.sections = optional config.dehumidifier.enable {
            title = "Dehumifier";
            type = "grid";
            priority = 5;
            cards = [
              {
                type = "tile";
                entity = "input_boolean.${name}_dehumidifier_automatic_control";
                name = "Automatic Control";
              }
              {
                type = "tile";
                entity = "switch.${config.dehumidifier.switchId}";
                name = "Running";
              }
              {
                type = "tile";
                entity = "binary_sensor.${name}_dehumidifier_full";
                name = "Tank Full";
                visibility = singleton {
                  condition = "state";
                  entity = "sensor.${name}_dehumidifier_full";
                  state = "on";
                };
                hide_state = true;
                color = "red";
                layout_options = {
                  grid_columns = 4;
                  grid_rows = 1;
                };
              }
              {
                type = "tile";
                entity = "sensor.${name}_mold_indicator";
                name = "Mold Indicator";
                icon = "mdi:molecule";
              }
              {
                type = "tile";
                entity = "sensor.${name}_critical_temperature";
                name = "Critical Temperature";
              }
              {
                type = "sensor";
                graph = "line";
                entity = "sensor.${name}_dehumidifier_tank_level";
                name = "Tank Level";
                grid_options.columns = 12;
                grid_options.rows = 2;
              }
            ];
          };
        }
      )
    );
  };

  config.services.home-assistant.config = mkMerge (
    mapAttrsToList (
      room: roomCfg:
      let
        inherit (roomCfg) formattedRoomName deviceId climate;
        inherit (roomCfg.dehumidifier)
          thresholds
          switchId
          powerId
          calibrationFactor
          ;
      in
      mkIf roomCfg.dehumidifier.enable {
        template = [
          {
            sensor = [
              {
                name = "${formattedRoomName} Dehumidifier Running";
                icon = "mdi:water";
                state = "{{ is_state('switch.${switchId}', 'on') and is_state('binary_sensor.${room}_dehumidifier_tank_full', 'off') }}";
              }

              {
                name = "${formattedRoomName} Critical Temperature";
                icon = "mdi:thermometer-alert";
                state = "{{ state_attr('sensor.${room}_mold_indicator', 'estimated_critical_temp') }}";
                unit_of_measurement = "°C";
              }

              {
                name = "${formattedRoomName} Dehumidifier Tank Level";
                unit_of_measurement = "%";
                icon = "mdi:gauge";
                state = ''
                  {% set runtime = states('sensor.${room}_dehumidifier_runtime') | float(0) %}
                  {% set fill_time = states('sensor.${room}_dehumidifier_fill_time') | float(108000) %}
                  {{ (runtime / fill_time * 100) | round(1) }}
                '';
              }
            ];
          }
          {
            trigger = singleton {
              platform = "state";
              entity_id = "switch.${switchId}";
              to = "on";
              for.minutes = 2;
            };

            binary_sensor = singleton {
              name = "${formattedRoomName} Dehumidifier Full";
              icon = "mdi:gauge-full";
              state = "{{ states('sensor.${powerId}') | float == 0 }}";
            };
          }
          {
            trigger = singleton {
              platform = "state";
              entity_id = "binary_sensor.${room}_dehumidifier_full";
              from = "on";
              to = "off";
            };

            sensor = singleton {
              name = "${formattedRoomName} Dehumidifier Fill Time";
              icon = "mdi:timer";
              state = "{{ states('${room}_dehumidifier_runtime') }}";
            };
          }
          {
            trigger = singleton {
              platform = "state";
              entity_id = "binary_sensor.${room}_dehumidifier_full";
              from = "on";
              to = "off";
              # To make sure it runs after the fill time sensor above triggers
              # as this will reset the runtime
              for.seconds = 30;
            };

            sensor = singleton {
              name = "${formattedRoomName} Dehumidifier Last Emptied";
              icon = "mdi:clock";
              state = "{{ now().timestamp() }}";
            };
          }
        ];

        input_boolean."${room}_dehumidifier_automatic_control" = {
          name = "${formattedRoomName} Dehumidifier Automatic Control";
          icon = "mdi:air-humidifier";
        };

        sensor = [
          {
            name = "${formattedRoomName} Mold Indicator";
            platform = "mold_indicator";
            indoor_temp_sensor = "sensor.${climate.temperature}";
            indoor_humidity_sensor = "sensor.${climate.humidity}";
            outdoor_temp_sensor = "sensor.outdoor_sensor_temperature";
            calibration_factor = calibrationFactor;
          }
          {
            name = "${formattedRoomName} Dehumidifier Runtime";
            platform = "history_stats";
            entity_id = "sensor.${room}_dehumidifier_running";
            state = "on";
            type = "time";
            start = "{{ states('sensor.${room}_dehumidifier_last_emptied') | float(0) }}";
            end = "{{ now() }}";
          }
        ];

        automation = [
          {
            alias = "${formattedRoomName} Dehumidifier Toggle";
            mode = "single";
            triggers = [
              {
                platform = "numeric_state";
                entity_id = [ "sensor.${room}_mold_indicator" ];
                above = thresholds.upper;
              }
              {
                platform = "numeric_state";
                entity_id = [ "sensor.${room}_mold_indicator" ];
                below = thresholds.lower;
              }
            ];
            conditions = singleton {
              condition = "state";
              entity_id = "input_boolean.${room}_dehumidifier_automatic_control";
              state = "on";
            };
            action = singleton {
              "if" = singleton {
                condition = "numeric_state";
                entity_id = "sensor.${room}_mold_indicator";
                above = thresholds.upper;
              };
              "then" = singleton {
                action = "switch.turn_on";
                target.entity_id = "switch.${switchId}";
              };
              "else" = singleton {
                action = "switch.turn_off";
                target.entity_id = "switch.${switchId}";
              };
            };
          }

          {
            alias = "${formattedRoomName} Dehumifier Full Notify";
            mode = "single";
            triggers = singleton {
              platform = "state";
              entity_id = "binary_sensor.${room}_dehumidifier_full";
              from = "off";
              to = "on";
            };
            actions = singleton {
              action = "notify.mobile_app_${deviceId}";
              data = {
                title = "Dehumidifier";
                message = "Tank full";
                data = {
                  channel = "Dehumidifier";
                  importance = "high";
                  priority = "high";
                  ttl = 0;
                };
              };
            };
          }
        ];
      }
    ) cfg.rooms
  );
}
