{ ns, lib, ... }:
let
  inherit (lib) mkEnableOption mkOption types;
in
{
  imports = lib.${ns}.scanPaths ./.;

  options.${ns}.desktop.services = {
    wayvnc.enable = mkEnableOption "WayVNC";

    waybar = {
      enable = mkEnableOption "Waybar";
      autoHideWorkspaces = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = ''
          List of workspace names that, when activated, cause the bar to
          automatically hide. Only works on Hyprland.
        '';
      };
    };

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
