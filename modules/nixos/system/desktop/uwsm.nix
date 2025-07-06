{
  lib,
  cfg,
  pkgs,
  config,
  sources,
  username,
  categoryCfg,
}:
let
  inherit (lib)
    ns
    mkIf
    hasInfix
    mkMerge
    mkOrder
    mkForce
    getExe'
    replaceStrings
    foldl'
    concatMapAttrs
    optionalString
    concatStringsSep
    mkOption
    literalExpression
    types
    optionals
    optionalAttrs
    ;
  inherit (config.${ns}.core) device home-manager;
  inherit (lib.${ns}) addPatches;
  homeUwsm = config.${ns}.hmNs.desktop.uwsm;
in
[
  {
    guardType = "first";
    enableOpt = false;
    conditions = [ config.programs.uwsm.enable ];

    opts = {
      enable = mkOption {
        type = types.bool;
        default = config.programs.uwsm.enable;
        readOnly = true;
      };

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

      serviceApps = mkOption {
        type = with types; listOf str;
        default = [ ];
        apply = v: (optionals home-manager.enable homeUwsm.serviceApps) ++ v;
        description = ''
          List of application desktop entry IDs that should be started in
          services instead of scopes. Useful for applications where we want to
          define custom shutdown behaviour.
        '';
      };

      appUnitOverrides = mkOption {
        type = types.attrs;
        default = { };
        apply = v: (optionalAttrs home-manager.enable homeUwsm.appUnitOverrides) // v;
        description = ''
          Attribute set of unit overrides. Attribute name should be the unit
          name without the app-''${desktop} prefix. Attribute value should be
          the multiline unit string.
        '';
      };

      fumon.enable = mkOption {
        type = types.bool;
        default = device.type != "laptop";
        description = ''
          Whether to enable Fumon service monitor. Warning: can cause CPU
          spikes when launching units so probably best to disable on low
          powered devices and laptops.
        '';
      };
    };

    asserts = [
      # Seems ok to nest UWSM start calls by using a UWSM desktop entry but we
      # should prefer to avoid it
      # https://github.com/NixOS/nixpkgs/pull/355416#issuecomment-2481432259
      (cfg.defaultDesktop != null -> !hasInfix "uwsm" cfg.defaultDesktop)
      ''
        The UWSM default desktop entry should not be a UWSM variant. Use the
        default non-UWSM desktop entry instead.
      ''
    ];

    environment = {
      systemPackages = [ pkgs.app2unit ];
      sessionVariables.APP2UNIT_SLICES = "a=app-graphical.slice b=background-graphical.slice s=session-graphical.slice";
      sessionVariables.APP2UNIT_TYPE = "scope";
    };

    systemd.user.services.fumon = {
      enable = cfg.fumon.enable;
      wantedBy = [ "graphical-session.target" ];
      path = mkForce [ ]; # reason explained in desktop/default.nix
      serviceConfig.ExecStart = [
        "" # to replace original ExecStart
        (getExe' config.programs.uwsm.package "fumon")
      ];
    };

    services.getty = mkMerge [
      (mkIf (!categoryCfg.displayManager.autoLogin) {
        # Automatically populate with primary user whilst still prompting for
        # password
        loginOptions = username;
        extraArgs = [ "--skip-login" ];
      })

      (mkIf categoryCfg.displayManager.autoLogin {
        autologinUser = username;
        autologinOnce = true;
      })
    ];

    # Only disable TTY clearing with autologin because it sometimes causes the
    # issue message to be printed over the login prompt
    systemd.services."getty@".serviceConfig.TTYVTDisallocate =
      mkIf categoryCfg.displayManager.autoLogin "no";

    # Remove excess new lines and use normal green instead of bright
    environment.etc.issue.text = ''
      [0;32m${replaceStrings [ "<<< " " >>>" ] [ "" "" ] config.services.getty.greetingLine}[0m
    '';

    security.loginDefs.settings = {
      # Disable timeout as with --skip-login the default timeout of 60 seconds
      # causes it to repeatedly timeout indefinitely
      LOGIN_TIMEOUT = 0;
    };

    environment.loginShellInit =
      let
        select = cfg.defaultDesktop == null;
      in
      mkIf (categoryCfg.displayManager.name == "uwsm") (
        mkOrder 2000
          # bash
          ''
            if [[ $(id -u) -ne 0 && -z $SSH_CONNECTION && -z $SSH_CLIENT && -z $SSH_TTY ]] && uwsm check may-start -q${optionalString select " && uwsm select"}; then
              UWSM_SILENT_START=1 exec uwsm start ${if select then "default" else "-- ${cfg.defaultDesktop}"}
            fi
          ''
      );

    systemd.user.units = concatMapAttrs (
      unitName: text:
      foldl' (
        acc: desktop:
        acc
        // {
          "app-${desktop}-${unitName}" = {
            inherit text;
            overrideStrategy = "asDropin";
          };
        }
      ) { } cfg.desktopNames
    ) cfg.appUnitOverrides;
  }

  {
    asserts = [
      (categoryCfg.displayManager.name == "uwsm" -> config.programs.uwsm.enable)
      "Using UWSM as a display manager requires it to be enabled"
    ];

    nixpkgs.overlays = [
      (final: prev: {
        uwsm = prev.uwsm.overrideAttrs {
          inherit (sources.uwsm) version;
          src = sources.uwsm;
        };

        app2unit = addPatches pkgs.${ns}.app2unit [
          (final.substitute {
            src = ../../../../patches/app2unit-service-apps.patch;
            substitutions = [
              "--replace-fail"
              "@SERVICE_APPS@"
              (concatStringsSep " " cfg.serviceApps)
            ];
          })
        ];
      })
    ];
  }
]
