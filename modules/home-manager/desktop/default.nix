{ lib
, pkgs
, config
, osConfig'
, ...
} @ args:
let
  inherit (lib)
    mkIf
    utils
    mkOption
    mkPackageOption
    length
    elem
    types
    literalExpression
    mkEnableOption;
  cfg = config.modules.desktop;

  terminalSubmodule = {
    options = {
      exePath = mkOption {
        type = types.str;
        default = null;
        example = literalExpression "${lib.getExe config.programs.alacritty.package}";
      };

      class = mkOption {
        type = types.str;
        default = null;
        example = "Alacritty";
        description = "Window class of the terminal";
      };
    };
  };
in
{
  imports = lib.utils.scanPaths ./.;

  options.modules.desktop = {
    enable = mkEnableOption "home-manager desktop modules";

    xdg.lowercaseUserDirs = mkEnableOption "lowercase user dirs" // {
      default = (osConfig'.modules.system.desktop.desktopEnvironment or false) == null;
    };

    windowManager = mkOption {
      type = types.nullOr (types.enum [ "hyprland" ]);
      default = null;
      description = "Window manager to use";
    };

    terminal = mkOption {
      type = types.submodule terminalSubmodule;
      default = null;
      description = "Information about the default terminal";
    };

    isWayland = mkOption {
      type = types.bool;
      internal = true;
      readOnly = true;
      default =
        cfg.enable &&
        ((elem cfg.windowManager utils.waylandWindowManagers)
        ||
        (elem osConfig'.modules.system.desktop.desktopEnvironment utils.waylandDesktopEnvironments));
    };

    style = {
      customTheme = mkEnableOption "custom GTK theme derived from base16 colorscheme" // {
        default = osConfig'.modules.system.desktop.desktopEnvironment == null;
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
          default = (utils.flakePkgs args "nix-resources").berkeley-mono-nerdfont;
          description = "Font package";
          example = literalExpression "pkgs.fira-code";
        };
      };

      cursor = {
        enable = mkEnableOption "custom cursor theme" // {
          default = osConfig'.modules.system.desktop.desktopEnvironment == null;
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
      cfg = config.modules.desktop;
      osDesktop = osConfig'.modules.system.desktop;
    in
    {
      assertions = mkIf cfg.enable (utils.asserts [
        (osConfig' != null)
        "Desktop modules are not supported on standalone home-manager deployments"
        osDesktop.enable
        "You cannot enable home-manager desktop if NixOS desktop is not enabled"
        (cfg.windowManager != null -> osDesktop.desktopEnvironment == null)
        "You cannot use a desktop environment with a window manager"
        (cfg.windowManager != null -> length osConfig'.device.monitors != 0)
        "Device monitors must be configured to use a window manager"
        (cfg.terminal != null)
        "Desktop default terminal must be set"
      ]);

      _module.args = {
        inherit (cfg) isWayland;
        desktopEnabled = cfg.enable;
      };
    };
}
