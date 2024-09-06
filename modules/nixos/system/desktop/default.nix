{
  ns,
  lib,
  pkgs,
  config,
  inputs,
  username,
  ...
}:
let
  inherit (lib)
    mkIf
    types
    mkEnableOption
    mkOption
    elem
    ;
  inherit (lib.${ns}) scanPaths waylandWindowManagers waylandDesktopEnvironments;
  inherit (config.${ns}.core) homeManager;
  inherit (config.${ns}.system.desktop) isWayland;
  cfg = config.${ns}.system.desktop;
in
{
  imports = (scanPaths ./.) ++ [ inputs.hyprland.nixosModules.default ];

  options.${ns}.system.desktop = {
    enable = mkEnableOption "desktop functionality";

    suspend.enable = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Whether to enable suspend to RAM. Disable on hosts where the hardware
        does not support it.
      '';
    };

    desktopEnvironment = mkOption {
      type =
        with types;
        nullOr (enum [
          "xfce"
          "gnome"
        ]);
      default = null;
      description = ''
        The desktop environment to use. The window manager is configured in
        home manager. Some windows managers don't require a desktop
        environment and some desktop environments include a window manager.
      '';
    };

    isWayland = mkOption {
      type = types.bool;
      readOnly = true;
      default =
        (
          if config.${ns}.core.homeManager.enable then
            (elem config.home-manager.users.${username}.${ns}.desktop.windowManager waylandWindowManagers)
          else
            false
        )
        || (elem cfg.desktopEnvironment waylandDesktopEnvironments);
    };
  };

  config = mkIf cfg.enable {
    i18n.defaultLocale = "en_GB.UTF-8";
    services.xserver.excludePackages = [ pkgs.xterm ];
    hardware.graphics.enable = true;

    # Enables wayland for all apps that support it
    environment.sessionVariables.NIXOS_OZONE_WL = mkIf isWayland "1";

    # Necessary for xdg-portal home-manager module to work with useUserPackages enabled
    # https://github.com/nix-community/home-manager/pull/5184
    # NOTE: When https://github.com/nix-community/home-manager/pull/2548 gets
    # merged this may no longer be needed
    environment.pathsToLink = mkIf homeManager.enable [
      "/share/xdg-desktop-portal"
      "/share/applications"
    ];

    systemd = mkIf (!cfg.suspend.enable) {
      targets = {
        sleep = {
          enable = false;
          unitConfig.DefaultDependencies = "no";
        };
        suspend = {
          enable = false;
          unitConfig.DefaultDependencies = "no";
        };
        hibernate = {
          enable = false;
          unitConfig.DefaultDependencies = "no";
        };
        hybrid-sleep = {
          enable = false;
          unitConfig.DefaultDependencies = "no";
        };
      };
    };
  };
}
