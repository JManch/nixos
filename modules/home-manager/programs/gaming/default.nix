{ lib
, config
, osConfig
, ...
}:
let
  inherit (lib)
    mkIf
    utils
    mkEnableOption
    mkOption
    types
    concatStringsSep
    concatStrings
    optional;
in
{
  imports = utils.scanPaths ./.;

  options.modules.programs.gaming = {
    mangohud.enable = mkEnableOption "MangoHud";
    r2modman.enable = mkEnableOption "r2modman";
    lutris.enable = mkEnableOption "Lutris";
    prism-launcher.enable = mkEnableOption "Prism Launcher";
    mint.enable = mkEnableOption "DRG Mod Loader";

    gameClasses = mkOption {
      type = with types; listOf str;
      default = [ ];
      description = ''
        List of game window classes that will be automatically moved to the
        gaming workspace and have tearing enabled. To disable tearing for a
        specific game add it to tearingExcludedClasses.
      '';
    };

    gameRegex = mkOption {
      type = types.str;
      internal = true;
      readOnly = true;
      apply = _: "^(${concatStringsSep "|" config.modules.programs.gaming.gameClasses})$";
    };

    tearingExcludedClasses = mkOption {
      type = with types; listOf str;
      default = [ ];
      description = ''
        List of game window classes that should be excluded from tearing.
      '';
    };

    tearingRegex = mkOption {
      type = types.str;
      internal = true;
      readOnly = true;
      apply =
        let
          inherit (config.modules.programs.gaming) tearingExcludedClasses gameClasses;
          tearingRegex = concatStringsSep "|" gameClasses;
          tearingExcludedRegex = concatStrings (
            map (class: "(?!${class}$)") tearingExcludedClasses
          );
        in
        _: "^${tearingExcludedRegex}(${tearingRegex})$";
      description = ''
        The complete regex expression for tearing that matches all game classes
        and excludes all excluded tearing classes.
      '';
    };
  };

  config =
    let
      osGaming = osConfig.modules.programs.gaming;
    in
    mkIf osGaming.enable {
      modules.programs.gaming.gameClasses =
        optional osGaming.gamescope.enable "\\.gamescope.*";
    };
}
