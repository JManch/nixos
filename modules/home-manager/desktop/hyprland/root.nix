{
  lib,
  cfg,
  pkgs,
  config,
}:
let
  inherit (lib)
    ns
    mkEnableOption
    mkOption
    types
    naturalSort
    attrNames
    nameValuePair
    imap0
    listToAttrs
    ;
  inherit (lib.${ns}) isHyprland;
in
{
  noChildren = true;
  defaultOpts.conditions = [ (isHyprland config) ];

  opts = {
    logging = mkEnableOption "logging";
    tearing = mkEnableOption "enable tearing";
    noGapsWhenOnly = mkEnableOption "no gaps when only";
    vrr = mkEnableOption "vrr";

    directScanout = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Whether to enable direct scanout with gamemode.
      '';
    };

    hyprcursor = {
      name = mkOption {
        type = types.str;
        description = "Hyprcursor name";
        default = "Hypr-Bibata-Modern-Classic";
      };

      package = mkOption {
        type = with types; nullOr package;
        default = pkgs.${ns}.bibata-hyprcursors;
        description = ''
          A Hyprcursor compatible cursor package. Set to null to disable Hyprcursor.
        '';
      };
    };

    blur = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to enable blur";
    };

    animations = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to enable workspace animations";
    };

    modKey = mkOption {
      type = types.str;
      default = "SUPER";
      description = "The modifier key to use for bindings";
    };

    secondaryModKey = mkOption {
      type = types.str;
      default = "ALT";
      description = ''
        Modifier key used for virtual machines or nested instances of
        hyprland to avoid clashes.
      '';
    };

    killActiveKey = mkOption {
      type = types.str;
      default = "W";
      description = "Key to use for killing the active window";
    };

    namedWorkspaces = mkOption {
      type = with types; attrsOf attrs;
      default = { };
      example = {
        GAME = {
          monitor = "DP-1";
        };
        VM = {
          monitor = "DP-1";
        };
      };
      description = ''
        Attribute set of named workspaces to create. Value is additional
        workspace rules to set for the workspace. Each workspace will be
        assigned a unique positive ID starting from 1000. This is to avoid the
        negative ID assignment for named workspaces which causes workspace
        transition animations to go the wrong direction.
      '';
    };

    namedWorkspaceIDs = mkOption {
      type = with types; attrsOf str;
      readOnly = true;
      description = ''
        Attribute set mapping named workspaces to unique IDs starting from 1000
      '';
      default = listToAttrs (
        imap0 (i: name: nameValuePair name (toString (1000 + i))) (
          naturalSort (attrNames cfg.namedWorkspaces)
        )
      );
    };

    options = mkOption {
      type = with types; attrsOf anything;
      default = { };
      description = ''
        Attribute set of options passed to the hl.config function.
      '';
    };

    windowRules = mkOption {
      type = with types; attrsOf anything;
      default = { };
      example = {
        nautilus-float = {
          match.class = "org\\.gnome\\.Nautilus";
          float = true;
        };
      };
      description = ''
        Attribute set of named window rules. Each value is passed straight to
        the `hl.window_rule` function so it holds a `match` attrset of matchers
        alongside the rule's effects. Rule `name` will be set to the attribute
        name.
      '';
    };

    workspaceRules = mkOption {
      type = with types; listOf attrs;
      default = { };
      description = "List of attributes defining workspace rules";
    };

    binds = mkOption {
      type = with types; listOf str;
      default = [ ];
      description = ''
        List of binds built with the `mkHyprBind` or `mkHyprExec` helpers.
      '';
    };

    extraConf = mkOption {
      type = types.lines;
      default = "";
      description = "Extra lua config";
    };
  };
}
