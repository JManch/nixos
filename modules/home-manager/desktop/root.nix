{
  lib,
  cfg,
  pkgs,
  args,
  osConfig,
}:
let
  inherit (lib)
    ns
    mkOption
    mkPackageOption
    length
    types
    literalExpression
    mkEnableOption
    ;
  osDesktop = osConfig.${ns}.system.desktop;
in
{
  enableOpt = true;
  defaultOpts.conditions = [ "desktop" ];

  opts = {
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
          default = (lib.${ns}.flakePkgs args "nix-resources").berkeley-mono-nerdfont;
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

  asserts = [
    (osConfig != null)
    "Desktop modules are not supported on standalone home-manager deployments"
    (cfg.terminal != null)
    "A default desktop terminal must be set"
    osDesktop.enable
    "You cannot enable home-manager desktop if NixOS desktop is not enabled"
    (cfg.windowManager != null -> osDesktop.desktopEnvironment == null)
    "You cannot use a desktop environment with a window manager"
    (cfg.windowManager != null -> length osConfig.${ns}.core.device.monitors != 0)
    "Device monitors must be configured to use a window manager"
  ];

  home.packages = with pkgs; [
    xdg-terminal-exec
    wl-clipboard
  ];

  xdg.configFile."xdg-terminals.list".text = ''
    ${cfg.terminal}.desktop
  '';

  dconf.settings = {
    "org/gtk/settings/file-chooser".show-hidden = true;
    "org/gtk/gtk4/settings/file-chooser".show-hidden = true;
  };
}
