{ lib, ... }:
let
  inherit (lib) mkEnableOption mkOption types;
in
{
  imports = lib.utils.scanPaths ./.;

  options.modules.desktop.services = {
    waybar.enable = mkEnableOption "Waybar";
    wlsunset.enable = mkEnableOption "wlsunset";

    swayidle = {
      enable = mkEnableOption "Swayidle";

      lockTime = mkOption {
        type = types.int;
        default = 3 * 60;
        description = "Idle seconds to lock screen";
      };

      screenOffTime = mkOption {
        type = types.int;
        default = 4 * 60;
        description = "Idle seconds to turn off screen";
      };
    };

    hypridle = {
      enable = mkEnableOption "Hypridle";

      lockTime = mkOption {
        type = types.int;
        default = 3 * 60;
        description = "Idle seconds to lock screen";
      };

      screenOffTime = mkOption {
        type = types.int;
        default = 4 * 60;
        description = "Idle seconds to turn off screen";
      };
    };
  };
}
