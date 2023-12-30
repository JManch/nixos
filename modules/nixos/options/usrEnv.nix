{ lib
, config
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
      compositor = mkOption {
        type = with types; nullOr (enum [ "hyprland" ]);
        description = "The desktop compositor to use";
      };
    };
  };
}
