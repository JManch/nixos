{
  lib,
  pkgs,
  config,
  username,
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
    getExe'
    mkOption
    elem
    ;
  inherit (lib.${ns})
    scanPaths
    waylandWindowManagers
    waylandDesktopEnvironments
    sliceSuffix
    ;
  inherit (config.${ns}.core) homeManager;
  cfg = config.${ns}.system.desktop;
in
{
  imports = scanPaths ./.;

  options.${ns}.system.desktop = {
    enable = mkEnableOption "desktop functionality";

    uwsm = {
      defaultDesktop = mkOption {
        type = with types; nullOr str;
        default = null;
        example = literalExpression "${pkgs.hyprland}/share/wayland-sessions/hyprland.desktop";
        description = ''
          If set, UWSM will automatically launch the set desktop without
          prompting for selection.
        '';
      };

      desktopNames = mkOption {
        type = with types; listOf str;
        internal = true;
        default = [ ];
        description = ''
          List of desktop names to create drop-in overrides for. Should be the
          exact case-sensitive name used in the .desktop file.
        '';
      };
    };

    suspend.enable = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Whether to enable suspend to RAM. Disable on hosts where the hardware
        does not support it.
      '';
    };

    displayManager = {
      name = mkOption {
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

      autoLogin = mkEnableOption ''
        auto graphical session login. Graphical session will lock with
        screensaver immediately. Auto login is not at all secure and should
        be used in combination with full disk encryption that does not
        auto-unlock with TPM.
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
    environment.sessionVariables.NIXOS_OZONE_WL = mkIf cfg.isWayland "1";

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

    # Locking here instead of in the idle daemon (e.g. hypridle) is more robust
    powerManagement.powerDownCommands =
      mkIf (cfg.desktopEnvironment == null) # bash
        ''
          # If our locker supports it, ignore the grace period and lock the screen
          # immediately to avoid accidentally unlocking in the sleep seconds.
          install -m644 -o ${username} -g users /dev/null /tmp/lock-immediately
          ${getExe' pkgs.systemd "loginctl"} lock-sessions
          sleep 3 # give lock screen time to open
        '';

    # Fix the session slice for home-manager services. I don't think it's
    # possible to do drop-in overrides like this with home-manager.

    # You'd expect service overrides with `systemd.user.services` to only set
    # what you've defined but confusingly Nixpkgs sets the service's PATH by
    # default in an undocumented way. This overrides the PATH set in the
    # systemd user environment and breaks our portal services.
    # https://github.com/NixOS/nixpkgs/blame/18bcb1ef6e5397826e4bfae8ae95f1f88bf59f4f/nixos/lib/systemd-lib.nix#L512

    # For system services this isn't an issue since `systemctl
    # show-environment` is basically empty anyway. For user services
    # however, this is a nasty pitfall. Note: this only affects overrides
    # of units provided in packages; not those declared with Nix.

    # We workaround this by instead defining plain unit files containing just
    # the set text. Setting `systemd.user.services.<name>.paths = mkForce []`
    # also works (it still adds extra Environment= vars however).
    systemd.user.units =
      genAttrs
        [
          "at-spi-dbus-bus.service"
          "xdg-desktop-portal-gtk.service"
          "xdg-desktop-portal-hyprland.service"
          "xdg-desktop-portal.service"
          "xdg-document-portal.service"
          "xdg-permission-store.service"
        ]
        (_: {
          overrideStrategy = "asDropin";
          text = ''
            [Service]
            Slice=session${sliceSuffix config}.slice
          '';
        });

    systemd.user.services = mkIf cfg.displayManager.autoLogin {
      boot-graphical-session-lock = {
        description = "Lock graphical session on boot";
        after = [
          "graphical-session.target"
          # For proper ordering lock services here must use Type=dbus and
          # BusName=org.freedesktop.ScreenSaver
          "hypridle.service"
        ];

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = pkgs.writeShellScript "lock-graphical-session" ''
            touch /tmp/lock-immediately
            loginctl lock-session
          '';
        };

        wantedBy = [ "graphical-session.target" ];
      };
    };
  };
}
