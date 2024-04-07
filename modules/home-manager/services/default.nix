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
  };
}
