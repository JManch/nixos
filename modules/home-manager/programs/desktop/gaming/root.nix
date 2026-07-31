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
    mkIf
    types
    concatStringsSep
    optional
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

        Should only be used for native games or games that do NOT support
        proton wayland as these clients do not get automatically assigned the
        "game" content type.
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

  ns.desktop.hyprland =
    let
      inherit (hyprland) namedWorkspaceIDs;
      concatRegex = regexes: "${concatStringsSep "|" regexes}";
      gameClassRegex = concatRegex cfg.gameClasses;
    in
    {
      namedWorkspaces.GAME = {
        monitor = primaryMonitor.name;
      };

      windowRules = {
        "x11-game-workspace" = {
          match.class = gameClassRegex;
          workspace = namedWorkspaceIDs.GAME;
          content = "game";
        };

        "game-workspace" = {
          match.content = 3;
          workspace = namedWorkspaceIDs.GAME;
        };

        "game-tearing" = mkIf hyprland.tearing {
          match = {
            content = 3; # 3 is game
            class = "negative:${concatRegex cfg.tearingExcludedClasses}";
            title = "negative:${concatRegex cfg.tearingExcludedClasses}";
          };
          immediate = true;
        };
      };

      binds = [
        (lib.${ns}.mkHyprBind "mod" "G" "hl.dsp.focus({ workspace = ${namedWorkspaceIDs.GAME} })")
        (lib.${ns}.mkHyprBind "mod_shift" "G"
          "hl.dsp.window.move({ workspace = ${namedWorkspaceIDs.GAME} })"
        )
      ];
    };
}
