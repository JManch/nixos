{
  lib,
  cfg,
  config,
  osConfig,
}:
let
  inherit (lib)
    ns
    mkEnableOption
    mkOption
    types
    concatStringsSep
    optional
    optionals
    ;
  inherit (config.${ns}.desktop) hyprland;
  inherit (osConfig.${ns}.core.device) primaryMonitor;
  osGaming = osConfig.${ns}.programs.gaming or null;
in
{
  conditions = [ "osConfigStrict.programs.gaming" ];

  opts = {
    gamemode.profiles = mkOption {
      type = types.attrsOf (
        types.submodule {
          options = {
            includeDefaultProfile = mkEnableOption "the default profile scripts in this profile";

            start = mkOption {
              type = types.lines;
              default = "";
            };

            stop = mkOption {
              type = types.lines;
              default = "";
            };
          };
        }
      );
      default = { };
      description = ''
        Script profiles to run in gamemode start/stop scripts. Profiles defined
        in HM must be mutually exclusive to those defined in NixOS.
      '';
    };

    gameClasses = mkOption {
      type = with types; listOf str;
      default = [ ];
      description = ''
        List of game window classes that will be automatically moved to the
        gaming workspace and have tearing enabled. To exclude a game from
        tearing add it to tearingExcludedClasses or tearingExcludedTitles.
      '';
    };

    tearingExcludedClasses = mkOption {
      type = with types; listOf str;
      default = [ ];
      description = ''
        Regex list of classes of games that should be excluded from tearing.
      '';
    };

    tearingExcludedTitles = mkOption {
      type = with types; listOf str;
      default = [ ];
      description = ''
        Regex list of titles of games that should be excluded from tearing.
      '';
    };
  };

  ns.programs.desktop.gaming.gameClasses = optional osGaming.gamescope.enable "\\.?gamescope.*";

  ns.desktop.hyprland = {
    namedWorkspaces.GAME = "monitor:${primaryMonitor.name}";
    settings =
      let
        inherit (hyprland) modKey namedWorkspaceIDs;
        concatRegex = regexes: "^(${concatStringsSep "|" regexes})$";
        gameClassRegex = concatRegex cfg.gameClasses;
      in
      {
        windowrulev2 =
          [
            "workspace ${namedWorkspaceIDs.GAME}, class:${gameClassRegex}"
          ]
          ++ optionals hyprland.tearing [
            "tag +tear_game, class:${gameClassRegex}"
            "tag -tear_game, tag:tear_game*, class:${concatRegex cfg.tearingExcludedClasses}"
            "tag -tear_game, tag:tear_game*, title:${concatRegex cfg.tearingExcludedTitles}"
            "prop immediate, tag:tear_game"
          ];

        bind = [
          "${modKey}, G, workspace, ${namedWorkspaceIDs.GAME}"
          "${modKey}SHIFT, G, movetoworkspace, ${namedWorkspaceIDs.GAME}"
        ];
      };
  };
}
