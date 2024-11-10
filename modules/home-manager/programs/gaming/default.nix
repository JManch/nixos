{
  ns,
  lib,
  config,
  osConfig',
  ...
}:
let
  inherit (lib)
    mkIf
    mkEnableOption
    mkOption
    types
    concatStringsSep
    concatStrings
    optional
    ;
  inherit (config.${ns}.desktop) hyprland;
  inherit (osConfig'.${ns}.device) primaryMonitor;
  cfg = config.${ns}.programs.gaming;
  osGaming = osConfig'.${ns}.programs.gaming or null;
in
{
  imports = lib.${ns}.scanPaths ./.;

  options.${ns}.programs.gaming = {
    mangohud.enable = mkEnableOption "MangoHud";
    r2modman.enable = mkEnableOption "r2modman";
    lutris.enable = mkEnableOption "Lutris";
    prism-launcher.enable = mkEnableOption "Prism Launcher";
    mint.enable = mkEnableOption "DRG Mod Loader";
    ryujinx.enable = mkEnableOption "Ryujinx";
    osu.enable = mkEnableOption "Osu";

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
      readOnly = true;
      apply = _: "^(${concatStringsSep "|" config.${ns}.programs.gaming.gameClasses})$";
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
      readOnly = true;
      apply =
        let
          inherit (config.${ns}.programs.gaming) tearingExcludedClasses gameClasses;
          tearingRegex = concatStringsSep "|" gameClasses;
          tearingExcludedRegex = concatStrings (map (class: "(?!${class}$)") tearingExcludedClasses);
        in
        _: "^${tearingExcludedRegex}(${tearingRegex})$";
      description = ''
        The complete regex expression for tearing that matches all game classes
        and excludes all excluded tearing classes.
      '';
    };
  };

  config = mkIf (osGaming.enable or false) {
    ${ns} = {
      programs.gaming.gameClasses = optional osGaming.gamescope.enable "\\.?gamescope.*";
      desktop.hyprland.namedWorkspaces.GAME = "monitor:${primaryMonitor.name}";
    };

    desktop.hyprland.settings =
      let
        inherit (hyprland) modKey namedWorkspaceIDs;
      in
      {
        windowrulev2 = [
          "workspace ${namedWorkspaceIDs.GAME}, class:${cfg.gameRegex}"
        ] ++ optional hyprland.tearing "immediate, class:${cfg.tearingRegex}";

        bind = [
          "${modKey}, G, workspace, ${namedWorkspaceIDs.GAME}"
          "${modKey}SHIFT, G, movetoworkspace, ${namedWorkspaceIDs.GAME}"
        ];
      };
  };
}
