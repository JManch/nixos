{
  lib,
  cfg,
  pkgs,
  osConfig,
}:
let
  inherit (lib)
    ns
    mkOption
    length
    types
    mkEnableOption
    ;
  inherit (lib.${ns}) modulesInDir;
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

    locker = mkOption {
      type = with types; nullOr (enum (modulesInDir ./programs/locker));
      default = null;
      description = "The locker to use";
    };

    launcher = mkOption {
      type = with types; nullOr (enum (modulesInDir ./programs/launcher));
      default = null;
      description = "The launcher to use";
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
    "You cannot use a window manager with a desktop environment"
    (cfg.windowManager != null -> length osConfig.${ns}.core.device.monitors != 0)
    "Device monitors must be configured to use a window manager"
    (cfg.locker != null -> osDesktop.desktopEnvironment == null)
    "You cannot use a locker with a desktop environment"
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
