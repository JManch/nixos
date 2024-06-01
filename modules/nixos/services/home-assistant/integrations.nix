{ lib, config, ... }:
let
  cfg = config.modules.services.hass;
in
lib.mkIf cfg.enableInternal
{
  services.home-assistant.config = {
    adaptive_lighting = [{
      name = "Joshua Room";
      # Adding lights individually rather than adding all with
      # light.joshua_room is preferred because, otherwise, adaptive lighting
      # turns on all lights even when just a single light is turned on.
      lights = [
        "light.joshua_lamp_floor_01"
        "light.joshua_strip_bed_01"
        "light.joshua_lamp_bed_01"
        "light.joshua_bulb_ceiling_01"
        "light.joshua_play_desk_01"
        "light.joshua_play_desk_02"
      ];
      min_brightness = 15;
      max_brightness = 100;
      min_color_temp = 2000;
      max_color_temp = 5000;
      sleep_brightness = 5;
      sleep_color_temp = 1000;
      transition_until_sleep = false;
      sunrise_time = "07:00:00";
      sunset_time = "22:30:00";
      # Offset sunset so that lights will be dark by the set sunset_time
      sunset_offset = -1800;
      brightness_mode = "tanh";
      brightness_mode_time_dark = 2600;
      brightness_mode_time_light = 900;
      take_over_control = false;
      skip_redundant_commands = true;
      intercept = true;
      multi_light_intercept = true;
    }];
  };
}
