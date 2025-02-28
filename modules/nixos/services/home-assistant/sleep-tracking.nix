{ lib, cfg }:
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
in
{
  opts.rooms = mkOption {
    type = types.attrsOf (
      types.submodule (
        { name, config, ... }:
        let
          inherit (config.sleepTracking) useAlarm wakeUpTimestamp sleepDuration;
          inherit (config) deviceId;
        in
        {
          options.sleepTracking = {
            enable = mkEnableOption "sleep tracking";

            useAlarm = mkEnableOption ''
              tracking sleep time using the device's next alarm. Only works on
              Android. If disabled, wake-up time must be manually set in the
              dashboard.
            '';

            wakeUpTimestamp = mkOption {
              type = types.str;
              readOnly = true;
              default =
                if useAlarm then
                  "as_timestamp(states('sensor.${deviceId}_next_alarm'), default = 0) | round(0)"
                else
                  "as_timestamp(today_at(states('input_datetime.${name}_wake_up_time')), default = 0) | round(0)";
              description = "Wake up timestamp expression to use in templates";
            };

            sleepTimestamp = mkOption {
              type = types.str;
              readOnly = true;
              default = "(${wakeUpTimestamp} - ${sleepDuration}*60*60)";
              description = "Sleep timestamp expression to use in templates";
            };

            sleepDuration = mkOption {
              type = types.str;
              readOnly = true;
              default = "(states('input_number.${name}_sleep_duration') | float(8))";
              description = "Sleep duration expression to use in templates";
            };
          };

          config.lovelace.sections = optional config.sleepTracking.enable {
            title = "Sleep Tracking";
            type = "grid";
            priority = 4;
            cards =
              optional (!useAlarm) {
                name = "Wake Up Time";
                type = "tile";
                entity = "input_datetime.${name}_wake_up_time";
                layout_options = {
                  grid_columns = 2;
                  grid_rows = 1;
                };
              }
              ++ singleton {
                name = "Sleep Duration";
                type = "tile";
                entity = "input_number.${name}_sleep_duration";
                layout_options = {
                  grid_columns = if useAlarm then 4 else 2;
                  grid_rows = 1;
                };
              };
          };
        }
      )
    );
  };

  services.home-assistant.config = mkMerge (
    mapAttrsToList (
      roomId: roomCfg:
      let
        inherit (roomCfg) formattedRoomName;
        inherit (roomCfg.sleepTracking) useAlarm;
      in
      mkIf roomCfg.sleepTracking.enable {
        input_number."${roomId}_sleep_duration" = {
          name = "${formattedRoomName} Sleep Duration";
          min = 5;
          max = 11;
          step = 0.5;
          icon = "mdi:bed-clock";
          unit_of_measurement = "h";
        };

        input_datetime = mkIf (!useAlarm) {
          "${roomId}_wake_up_time" = {
            name = "${formattedRoomName} Wake Up Time";
            has_time = true;
          };
        };
      }
    ) cfg.rooms
  );
}
