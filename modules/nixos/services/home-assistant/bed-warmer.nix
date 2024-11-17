{
  ns,
  lib,
  config,
  ...
}:
let
  inherit (lib)
    mkIf
    mkMerge
    types
    mkOption
    optional
    mkEnableOption
    mapAttrsToList
    singleton
    ;
  cfg = config.${ns}.services.hass;
in
{
  options.${ns}.services.hass.rooms = mkOption {
    type = types.attrsOf (
      types.submodule (
        { name, config, ... }:
        let
          inherit (config) sleepTracking;
          inherit (config.bedWarmer) switchId;
        in
        {
          options = {
            bedWarmer = {
              enable = mkEnableOption "smart bed warmer integration";

              switchId = mkOption {
                type = types.str;
                example = "joshua_bed_warmer";
                description = "Entity ID of the bed warmer switch";
              };
            };
          };

          config.lovelace.sections = optional config.bedWarmer.enable {
            title = "Bed Warmer";
            priority = 6;
            type = "grid";
            cards =
              optional sleepTracking.enable {
                type = "tile";
                name = "Automatic Control";
                entity = "input_boolean.${name}_bed_warmer_automatic_control";
                color = "red";
              }
              ++ singleton {
                type = "tile";
                name = "Running";
                entity = "switch.${switchId}";
              }
              ++ optional sleepTracking.enable {
                type = "tile";
                name = "Enable Temperature";
                entity = "input_number.${name}_bed_warmer_enable_temperature";
              }
              ++ singleton {
                type = "tile";
                name = "Run Time";
                entity = "input_number.${name}_bed_warmer_run_time";
                icon = "mdi:timer";
              };
          };
        }
      )
    );
  };

  config.services.home-assistant.config = mkMerge (
    mapAttrsToList (
      room: roomCfg:
      let
        inherit (roomCfg) formattedRoomName sleepTracking climate;
        inherit (roomCfg.bedWarmer) switchId;
      in
      mkIf roomCfg.bedWarmer.enable {
        input_number = {
          "${room}_bed_warmer_run_time" = {
            name = "${formattedRoomName} Bed Warmer Run Time";
            mode = "box";
            min = 5;
            max = 240;
            unit_of_measurement = "min";
            icon = "mdi:timer";
          };

          "${room}_bed_warmer_enable_temperature" = mkIf sleepTracking.enable {
            name = "${formattedRoomName} Bed Warmer Enable Temperature";
            mode = "box";
            min = 18;
            max = 22;
            unit_of_measurement = "°C";
            icon = "mdi:thermometer";
          };
        };

        input_boolean."${room}_bed_warmer_automatic_control" = mkIf sleepTracking.enable {
          name = "${formattedRoomName} Bed Warmer Automatic Control";
          icon = "mdi:bed-empty";
        };

        automation =
          singleton {
            alias = "${formattedRoomName} Bed Warmer Disable";
            triggers = singleton {
              trigger = "state";
              entity_id = [ "switch.${switchId}" ];
              to = "on";
              for.minutes = "{{ states('input_number.${room}_bed_warmer_run_time') }}";
            };
            actions = singleton {
              action = "switch.turn_off";
              target.entity_id = "switch.${switchId}";
            };
          }
          ++ optional sleepTracking.enable {
            alias = "${formattedRoomName} Bed Warmer Enable";
            mode = "single";
            triggers = singleton {
              platform = "template";
              # Enable 5 mins before sleep time
              value_template = "{{ (now().timestamp() + 5*60) | round(0) == ${sleepTracking.sleepTimestamp} }}";
            };
            conditions = singleton {
              condition = "template";
              value_template = "{{ states('sensor.${climate.temperature}') | float <= states('input_number.${room}_bed_warmer_enable_temperature') | float }}";
            };
            actions = singleton {
              action = "switch.turn_on";
              target.entity_id = "switch.${switchId}";
            };
          };

        # TODO: Button automations for controlling with remote
      }
    ) cfg.rooms
  );
}
