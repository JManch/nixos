{ lib, osConfig, ... }:
let
  inherit (lib)
    mkIf
    utils
    mkEnableOption
    mkOption
    types
    concatStringsSep
    optional;
in
{
  imports = utils.scanPaths ./.;

  options.modules.programs.gaming = {
    mangohud.enable = mkEnableOption "MangoHud";
    r2modman.enable = mkEnableOption "r2modman";
    lutris.enable = mkEnableOption "Lutris";
    prism-launcher.enable = mkEnableOption "Prism Launcher";

    windowClassRegex = mkOption {
      type = types.listOf types.str;
      default = [ ];
      apply = v: "^(${concatStringsSep "|" v})$";
      description = "List of regex matches for game window classes";
    };
  };

  config =
    let
      inherit (osConfig.modules.programs) gaming;
    in
    mkIf gaming.enable {
      modules.programs.gaming.windowClassRegex =
        optional gaming.gamescope.enable "\\.gamescope.*";
    };
}
