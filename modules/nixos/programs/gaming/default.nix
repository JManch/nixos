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

    gamemode = {
      enable = mkEnableOption "Gamemode";

      startScript = mkOption {
        type = types.lines;
        default = "";
        description = "Bash script to run when gamemode starts";
      };

      stopScript = mkOption {
        type = types.lines;
        default = "";
        description = "Bash script to run when gamemode stops";
      };
    };
  };
}
