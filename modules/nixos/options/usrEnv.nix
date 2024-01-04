{ lib
, ...
}:
let
  inherit (lib) mkEnableOption mkOption types;
in
{
  options.usrEnv = {
    homeManager.enable = mkEnableOption "use home manager";
    desktop = {
      enable = mkEnableOption "have a desktop environment";
      desktopManager = mkOption {
        type = with types; nullOr (enum [ "xfce" "plasma" ]);
        default = null;
        description = "The desktop manager to use";
      };
      desktopManagerWindowManager = mkOption {
        type = types.bool;
        default = true;
        description = "Whether to use the desktop manager's built in window manager (if it has one)";
      };
    };
  };
}
