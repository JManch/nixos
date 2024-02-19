{ lib, ... }:
let
  inherit (lib) mkEnableOption mkOption types;
in
{
  imports = lib.utils.scanPaths ./.;

  options.modules.programs.gaming = {
    enable = mkEnableOption "gaming optimisations";
    steam.enable = mkEnableOption "Steam";
    gamescope.enable = mkEnableOption "Gamescope";
    gamemode.enable = mkEnableOption "Gamemode";

    windowClassRegex = mkOption {
      type = types.str;
      default = "^(steam_app.*|\.gamescope.*)$";
      description = "Regex to match game window classes";
    };
  };
}
