{ lib, ... }:
let
  inherit (lib) mkEnableOption mkOption types;
in
{
  options.usrEnv = {
    homeManager.enable = mkEnableOption "home manager";
    desktop = {
      enable = mkEnableOption "desktop functionality";
      desktopEnvironment = mkOption {
        type = with types; nullOr (enum [ "xfce" "plasma" "gnome" ]);
        default = null;
        description = "The desktop manager to use";
      };
      # Window manager is configured in home-manager
    };
  };
}
