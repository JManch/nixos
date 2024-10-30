{ ns, lib, ... }:
let
  inherit (lib) mkEnableOption mkOption types;
in
{
  imports = lib.${ns}.scanPaths ./.;

  options.${ns}.programs.gaming = {
    enable = mkEnableOption "gaming optimisations";
    steam.enable = mkEnableOption "Steam";
    gamescope.enable = mkEnableOption "Gamescope";

    gamemode = {
      enable = mkEnableOption "Gamemode";

      customPackage = mkOption {
        type = types.package;
        readOnly = true;
        description = ''
          Wrapped gamemode package that supports passing custom args to
          gamemoderun
        '';
      };

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
