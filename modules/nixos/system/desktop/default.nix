{
  lib,
  pkgs,
  config,
  ...
}:
let
  inherit (lib)
    ns
    mkIf
    types
    mkEnableOption
    literalExpression
    genAttrs
    mkOption
    elem
    ;
  inherit (lib.${ns}) scanPaths waylandWindowManagers waylandDesktopEnvironments;
  inherit (config.${ns}.core) homeManager;
  inherit (config.${ns}.system.desktop) isWayland;
  cfg = config.${ns}.system.desktop;
in
{
  imports = scanPaths ./.;

  options.${ns}.system.desktop = {
    enable = mkEnableOption "desktop functionality";

    uwsm.defaultDesktop = mkOption {
      type = with types; nullOr str;
      default = null;
      example = literalExpression "${pkgs.hyprland}/share/wayland-sessions/hyprland.desktop";
      description = ''
        If set, UWSM will automatically launch the set desktop without
        prompting for selection.
      '';
    };

    suspend.enable = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Whether to enable suspend to RAM. Disable on hosts where the hardware
        does not support it.
      '';
    };

    displayManager = mkOption {
      type =
        with types;
        nullOr (enum [
          "greetd"
          "uwsm"
        ]);
      default = null;
      description = ''
        The display manager to use. If null, will be nothing or whatever the
        desktop environment uses.
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

    gnome = {
      advancedBinds = mkEnableOption "advanced binds";

      workspaceCount = mkOption {
        type = types.ints.between 1 10;
        default = 4;
        description = "Number of Gnome workspaces to create";
      };
    };

    isWayland = mkOption {
      type = types.bool;
      readOnly = true;
      default =
        (
          if config.${ns}.core.homeManager.enable then
            (elem config.hm.${ns}.desktop.windowManager waylandWindowManagers)
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

    # Some apps like vscode needs this
    services.gnome.gnome-keyring.enable = true;

    # Necessary for xdg-portal home-manager module to work with useUserPackages enabled
    # https://github.com/nix-community/home-manager/pull/5184
    # NOTE: When https://github.com/nix-community/home-manager/pull/2548 gets
    # merged this may no longer be needed
    environment.pathsToLink = mkIf homeManager.enable [
      "/share/xdg-desktop-portal"
      "/share/applications"
    ];

    systemd.targets = mkIf (!cfg.suspend.enable) (
      genAttrs
        [
          "sleep"
          "suspend"
          "hibernate"
          "hybrid-sleep"
        ]
        (_: {
          enable = false;
          unitConfig.DefaultDependencies = false;
        })
    );
  };
}
