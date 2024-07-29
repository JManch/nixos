{
  lib,
  config,
  inputs,
  ...
}:
let
  inherit (lib) utils mapAttrs;
  inherit (secrets.general) people;
  cfg = config.modules.services.hass;
  secrets = inputs.nix-resources.secrets.hass { inherit lib config; };
  upperPeople = mapAttrs (_: p: utils.upperFirstChar p) people;
in
lib.mkIf cfg.enableInternal {
  services.home-assistant.config = {
    adaptive_lighting = [
      {
        name = "Joshua Room";
        # Adding lights individually rather than adding all with
        # light.joshua_room_lights is preferred because, otherwise, adaptive
        # lighting turns on all lights even when just a single light is turned
        # on.
        lights = [
          "light.joshua_lamp_floor"
          "light.joshua_lamp_bed"
          "light.joshua_bulb_ceiling"
          "light.joshua_play_desk_1"
          "light.joshua_play_desk_2"
        ];
        min_brightness = 20;
        sleep_brightness = 5;
        sleep_color_temp = 1000;
        sunrise_time = "07:00:00";
        sunset_time = "22:30:00";
        brightness_mode = "tanh";
        brightness_mode_time_dark = 2600;
        brightness_mode_time_light = 900;
        take_over_control = false;
        skip_redundant_commands = true;
      }
      {
        name = "Lounge";
        lights = [ "light.lounge_lights" ];
        min_brightness = 50;
        take_over_control = true;
        skip_redundant_commands = true;
      }
      {
        name = "${upperPeople.person1} Room";
        lights = [ "light.${people.person1}_lamp_desk" ];
        min_brightness = 5;
        sunrise_time = "07:00:00";
        sunset_time = "22:30:00";
        brightness_mode = "tanh";
        brightness_mode_time_dark = 2600;
        brightness_mode_time_light = 900;
        take_over_control = false;
        skip_redundant_commands = true;
      }
    ];
  };
}
