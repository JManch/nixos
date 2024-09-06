{ ns, lib, ... }:
let
  inherit (lib) mkOption types mkEnableOption;
in
{
  imports = lib.${ns}.scanPaths ./.;

  options.${ns}.services = {
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

    hass.curlCommand = mkOption {
      type = types.functionTo types.lines;
      description = ''
        Function for generating a curl command to query the hass API
      '';
    };
  };
}
