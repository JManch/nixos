{
  lib,
  cfg,
  args,
  pkgs,
  config,
}:
let
  inherit (lib)
    ns
    mkAliasOptionModule
    mkEnableOption
    mkOption
    types
    naturalSort
    attrNames
    nameValuePair
    imap0
    listToAttrs
    ;
  inherit (lib.${ns}) isHyprland flakePkgs;
in
{
  noChildren = true;
  defaultOpts.conditions = [ (isHyprland config) ];

  imports = [
    (mkAliasOptionModule
      [
        ns
        "desktop"
        "hyprland"
        "binds"
      ]
      [
        "wayland"
        "windowManager"
        "hyprland"
        "settings"
        "bind"
      ]
    )

    (mkAliasOptionModule
      [
        ns
        "desktop"
        "hyprland"
        "settings"
      ]
      [
        "wayland"
        "windowManager"
        "hyprland"
        "settings"
      ]
    )
  ];

  opts = {
    logging = mkEnableOption "logging";
    tearing = mkEnableOption "enable tearing";
    plugins = mkEnableOption "plugins";
    vrr = mkEnableOption "vrr";
    directScanout = mkEnableOption ''
      enable direct scanout. Direct scanout reduces input lag for fullscreen
      applications however might cause graphical glitches.
    '';

    hyprcursor = {
      name = mkOption {
        type = types.str;
        description = "Hyprcursor name";
        default = "Hypr-Bibata-Modern-Classic";
      };

      package = mkOption {
        type = with types; nullOr package;
        default = (flakePkgs args "nix-resources").bibata-hyprcursors;
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
      description = "Whether to enable animations";
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

    shaderDir = mkOption {
      type = types.str;
      readOnly = true;
      default = "${config.xdg.configHome}/hypr/shaders";
    };

    namedWorkspaces = mkOption {
      type = types.attrsOf types.str;
      default = { };
      example = {
        GAME = "monitor:DP-1";
        VM = "monitor:DP-1";
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

    socketListenerExtraLines = mkOption {
      type = types.lines;
      default = "";
      description = ''
        Extra lines inserted at the start of the socket listener script.
      '';
    };

    eventScripts = mkOption {
      type = with types; attrsOf lines;
      default = { };
      description = ''
        Attribute set where the names are hyprland socket events and the values
        are scripts to run when the event fires. The socket listener runs in a
        systemd service.
      '';
    };
  };
}
