{
  lib,
  pkgs,
  config,
  osConfig,
  ...
}@args:
let
  inherit (lib)
    ns
    mkIf
    mkMerge
    mkOption
    mkPackageOption
    length
    elem
    types
    literalExpression
    mkEnableOption
    ;
  inherit (lib.${ns})
    scanPaths
    asserts
    flakePkgs
    waylandWindowManagers
    waylandDesktopEnvironments
    ;
  cfg = config.${ns}.desktop;
in
{
  imports = scanPaths ./.;

  options.${ns}.desktop = {
    enable = mkEnableOption "home-manager desktop modules";

    xdg.lowercaseUserDirs = mkEnableOption "lowercase user dirs" // {
      default = (osConfig.${ns}.system.desktop.desktopEnvironment or false) == null;
    };

    terminal = mkOption {
      type = with types; nullOr str;
      default = null;
      example = "Alacritty";
      description = ''
        XDG desktop ID of the default terminal to use with xdg-terminal-exec.
        The terminal should have its desktop entry modified to comply with the
        xdg-terminal-exec spec.
      '';
    };

    windowManager = mkOption {
      type = types.nullOr (types.enum [ "hyprland" ]);
      default = null;
      description = "Window manager to use";
    };

    isWayland = mkOption {
      type = types.bool;
      readOnly = true;
      default =
        cfg.enable
        && (
          (elem cfg.windowManager waylandWindowManagers)
          || (elem osConfig.${ns}.system.desktop.desktopEnvironment waylandDesktopEnvironments)
        );
    };

    style = {
      customTheme = mkEnableOption "custom GTK theme derived from base16 colorscheme" // {
        default = osConfig.${ns}.system.desktop.desktopEnvironment == null;
      };

      font = {
        family = mkOption {
          type = types.str;
          default = "BerkeleyMono Nerd Font";
          description = "Font family name";
          example = "Fira Code";
        };

        package = mkOption {
          type = types.package;
          default = (flakePkgs args "nix-resources").berkeley-mono-nerdfont;
          description = "Font package";
          example = literalExpression "pkgs.fira-code";
        };
      };

      cursor = {
        enable = mkEnableOption "custom cursor theme" // {
          default = osConfig.${ns}.system.desktop.desktopEnvironment == null;
        };

        package = mkPackageOption pkgs "bibata-cursors" { };

        name = mkOption {
          type = types.str;
          description = "Cursor name";
          default = "Bibata-Modern-Classic";
        };

        size = mkOption {
          type = types.int;
          default = 24;
          description = "Cursor size in pixels";
        };
      };

      cornerRadius = mkOption {
        type = types.int;
        default = 10;
        description = "Corner radius to use for all styled applications";
      };

      borderWidth = mkOption {
        type = types.int;
        default = 2;
        description = "Border width in pixels for all desktop applications";
      };

      gapSize = mkOption {
        type = types.int;
        default = 10;
        description = "Gap size in pixels for all desktop applications";
      };
    };
  };

  config =
    let
      cfg = config.${ns}.desktop;
      osDesktop = osConfig.${ns}.system.desktop;
    in
    mkMerge [
      {
        _module.args = {
          inherit (cfg) isWayland;
          desktopEnabled = cfg.enable;
        };
      }

      (mkIf cfg.enable {
        assertions = asserts [
          (osConfig != null)
          "Desktop modules are not supported on standalone home-manager deployments"
          (cfg.terminal != null)
          "A default desktop terminal must be set"
          osDesktop.enable
          "You cannot enable home-manager desktop if NixOS desktop is not enabled"
          (cfg.windowManager != null -> osDesktop.desktopEnvironment == null)
          "You cannot use a desktop environment with a window manager"
          (cfg.windowManager != null -> length osConfig.${ns}.device.monitors != 0)
          "Device monitors must be configured to use a window manager"
        ];

        home.packages = [ pkgs.xdg-terminal-exec ];

        xdg.configFile."xdg-terminals.list".text = ''
          ${cfg.terminal}.desktop
        '';
      })
    ];
}
