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
          inherit (config.bedWarmer) switchId;
        in
        {
          options = {
            bedWarmer = {
              enable = mkEnableOption "smart bed warmer integration";

              thresholdTemp = mkOption {
                type = types.float;
                default = 19.0;
                description = ''
                  Bed warmer will enable before sleep time if room temperature is
                  below this value
                '';
              };

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
            cards = [
              {
                type = "tile";
                name = "Running";
                entity = "switch.${switchId}";
                icon = "mdi:bed-empty";
                color = "red";
              }
              {
                type = "tile";
                name = "Run time";
                entity = "input_number.${name}_bed_warmer_run_time";
                icon = "mdi:timer";
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
        inherit (roomCfg) formattedRoomName sleepTracking sensors;
        inherit (roomCfg.bedWarmer) switchId thresholdTemp;
      in
      mkIf roomCfg.bedWarmer.enable {
        input_number."${room}_bed_warmer_run_time" = {
          name = "${formattedRoomName} Bed Warmer Run Time";
          mode = "box";
          min = 1;
          max = 240;
          initial = 20;
          unit_of_measurement = "min";
          icon = "mdi:timer";
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
              value_template = "{{ (now().timestamp() + states('input_number.${room}_bed_warmer_run_time') | float * 60) | round(0) == ${sleepTracking.wakeUpTimestamp} }}";
            };
            conditions = singleton {
              condition = "numeric_state";
              entity_id = "sensor.${sensors.temperature}";
              below = thresholdTemp;
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
