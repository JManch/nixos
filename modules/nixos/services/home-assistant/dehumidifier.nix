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
                entity = "sensor.${name}_dehumidifier_tank_status";
                name = "Tank Status";
                visibility = singleton {
                  condition = "state";
                  entity = "sensor.${name}_dehumidifier_tank_status";
                  state = "Full";
                };
                color = "red";
                icon = "";
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
            ];
          };
        }
      )
    );
  };

  config.services.home-assistant.config = mkMerge (
    mapAttrsToList (
      roomId: roomCfg:
      let
        inherit (roomCfg) formattedRoomName deviceId sensors;
        inherit (roomCfg.dehumidifier)
          thresholds
          switchId
          powerId
          calibrationFactor
          ;
      in
      mkIf roomCfg.dehumidifier.enable {
        template = singleton {
          sensor = [
            {
              name = "${formattedRoomName} Dehumidifier Tank Status";
              icon = "mdi:water";
              state = ''
                {% if is_state('switch.${switchId}', 'off') %}
                  Unknown
                {% elif is_state('switch.${switchId}', 'on') and states('sensor.${powerId}') | float == 0 %}
                  Full
                {% else %}
                  Ok
                {% endif %}
              '';
            }
            {
              name = "${formattedRoomName} Critical Temperature";
              icon = "mdi:thermometer-alert";
              state = "{{ state_attr('sensor.${roomId}_mold_indicator', 'estimated_critical_temp') }}";
              unit_of_measurement = "°C";
            }
          ];
        };

        input_boolean = {
          "${roomId}_dehumidifier_automatic_control" = {
            name = "${formattedRoomName} Dehumidifier Automatic Control";
            icon = "mdi:air-humidifier";
          };
        };

        sensor = singleton {
          name = "${formattedRoomName} Mold Indicator";
          platform = "mold_indicator";
          indoor_temp_sensor = "sensor.${sensors.temperature}";
          indoor_humidity_sensor = "sensor.${sensors.humidity}";
          outdoor_temp_sensor = "sensor.outdoor_sensor_temperature";
          calibration_factor = calibrationFactor;
        };

        automation = [
          {
            alias = "${formattedRoomName} Dehumidifier Toggle";
            mode = "single";
            triggers = [
              {
                platform = "numeric_state";
                entity_id = [ "sensor.${roomId}_mold_indicator" ];
                above = thresholds.upper;
              }
              {
                platform = "numeric_state";
                entity_id = [ "sensor.${roomId}_mold_indicator" ];
                below = thresholds.lower;
              }
            ];
            conditions = singleton {
              condition = "state";
              entity_id = "input_boolean.${roomId}_dehumidifier_automatic_control";
              state = "on";
            };
            action = singleton {
              "if" = singleton {
                condition = "numeric_state";
                entity_id = "sensor.${roomId}_mold_indicator";
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
              entity_id = "sensor.${roomId}_dehumidifier_tank_status";
              to = "Full";
              for.minutes = 1;
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
