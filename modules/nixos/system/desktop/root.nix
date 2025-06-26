{
  lib,
  cfg,
  pkgs,
  config,
}:
let
  inherit (lib)
    ns
    mkIf
    types
    mkDefault
    genAttrs
    mkOption
    singleton
    mkEnableOption
    ;
  inherit (config.${ns}.core) home-manager device;
  inherit (config.${ns}.hmNs.desktop.programs) locker;
  homeDesktop = config.${ns}.hmNs.desktop;
in
{
  enableOpt = true;

  opts = {
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
        auto graphical session login. Should only be used in combination with
        full disk encryption requiring a passphrase or TPM pin. The graphical
        session will still lock after sleep or suspend.
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
  };

  i18n.defaultLocale = "en_GB.UTF-8";
  services.xserver.excludePackages = [ pkgs.xterm ];
  hardware.graphics.enable = true;

  # Some apps may use this to optimise for power savings
  services.upower.enable = mkDefault (device.type == "laptop");
  # Service doesn't autostart otherwise https://github.com/NixOS/nixpkgs/issues/81138
  systemd.services.upower.wantedBy = mkIf config.services.upower.enable [ "graphical.target" ];

  # Enables wayland for all apps that support it
  environment.sessionVariables.NIXOS_OZONE_WL = 1;

  # Some apps like vscode need the keyring for saving credentials.
  # WARN: May need to manually create a "login" keyring for this to work
  # correctly. Seahorse is an easy way to do this. To enable automatic
  # keyring unlock on login use the same password as our user.
  services.gnome.gnome-keyring.enable = true;
  ns.persistenceHome.directories = singleton {
    directory = ".local/share/keyrings";
    mode = "0700";
  };

  # Necessary for xdg-portal home-manager module to work with useUserPackages enabled
  # https://github.com/nix-community/home-manager/pull/5184
  # NOTE: When https://github.com/nix-community/home-manager/pull/2548 gets
  # merged this may no longer be needed
  environment.pathsToLink = mkIf home-manager.enable [
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

  environment.etc."systemd/system-sleep/post-hibernate-unlock-graphical-session" =
    mkIf
      (
        cfg.displayManager.autoLogin
        && home-manager.enable
        && homeDesktop.enable
        && locker.package != null
        && locker.unlockCmd != null
      )
      {
        source = pkgs.writeShellScript "post-hibernate-unlock-graphical-session" ''
          if [ "$1-$SYSTEMD_SLEEP_ACTION" = "post-hibernate" ]; then
            ${locker.unlockCmd}
          fi
        '';
      };

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
          Slice=session${lib.${ns}.sliceSuffix config}.slice
        '';
      });

  systemd.user.services = mkIf (cfg.desktopEnvironment == null) {
    "notify-ac-plugged-in" = {
      description = "Notify AC Plugged In";
      after = [ "graphical-session.target" ];
      requisite = [ "graphical-session.target" ];
      wantedBy = [ "ac.target" ];
      unitConfig.ConditionUser = "!@system";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = pkgs.writeShellScript "notify-ac-plugged-in" ''
          ${lib.getExe pkgs.libnotify} --urgency=low -t 5000 "Power" "AC plugged in"
        '';
      };
    };

    "notify-ac-unplugged" = {
      description = "Notify AC Unplugged";
      after = [ "graphical-session.target" ];
      requisite = [ "graphical-session.target" ];
      wantedBy = [ "battery.target" ];
      unitConfig.ConditionUser = "!@system";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = pkgs.writeShellScript "notify-unplugged" ''
          ${lib.getExe pkgs.libnotify} --urgency=low -t 5000 "Power" "AC unplugged"
        '';
      };
    };
  };
}
