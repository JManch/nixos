{ lib, ... }:
let
  inherit (lib) mkEnableOption mkOption types;
in
{
  imports = lib.utils.scanPaths ./.;

  options.modules.desktop.services = {
    waybar.enable = mkEnableOption "Waybar";
    wayvnc.enable = mkEnableOption "WayVNC";

    wlsunset = {
      enable = mkEnableOption "wlsunset";
      transition = mkEnableOption ''
        gradually transitioning the screen temperature until sunset instead of
        suddenly switching at the set time. Warning: this tends to cause
        stuttering and artifacting as the transition is happening.
      '';
    };

    hypridle = {
      enable = mkEnableOption "Hypridle";
      debug = mkEnableOption "a low timeout idle notification for debugging";

      lockTime = mkOption {
        type = types.int;
        default = 3 * 60;
        description = "Idle seconds to lock screen";
      };

      screenOffTime = mkOption {
        type = types.int;
        default = 30;
        description = "Seconds to turn off screen after locking";
      };
    };
  };
}
