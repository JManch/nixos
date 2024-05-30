{ lib, ... }:
let
  inherit (lib) mkOption types mkEnableOption;
in
{
  imports = lib.utils.scanPaths ./.;

  options.modules.services = {
    easyeffects.enable = mkEnableOption "Easyeffects";

    syncthing = {
      enable = mkEnableOption "Syncthing";
      exposeWebGUI = mkEnableOption "exposing the web GUI";

      port = mkOption {
        type = types.port;
        default = 8384;
        description = "Web GUI listening port";
      };
    };

    hass.solarLightThreshold = mkOption {
      type = types.float;
      default = 1.0;
      description = ''
        Solar power threshold that is considered bright enough to warrant
        turning off the lights and enabling light mode.
      '';
    };
  };
}
