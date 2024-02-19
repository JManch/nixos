{ lib, ... }:
let
  inherit (lib) mkEnableOption mkOption types;
in
{
  options.usrEnv = {
    homeManager.enable = mkEnableOption "Home Manager";

    desktop = {
      enable = mkEnableOption "desktop functionality";

      desktopEnvironment = mkOption {
        # NOTE: The window manager is configured in home manager. Some windows
        # managers don't require a desktop environment and some desktop
        # environments include a window manager.
        type = with types; nullOr (enum [ "xfce" "plasma" "gnome" ]);
        default = null;
      };
    };
  };
}
