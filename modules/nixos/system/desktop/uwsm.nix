{
  lib,
  cfg,
  pkgs,
  config,
  selfPkgs,
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
  inherit (lib.${ns}) asserts addPatches;
  homeUwsm = config.hm.${ns}.desktop.uwsm;
in
[
  {
    guardType = "first";
    enableOpt = false;
    conditions = [ config.programs.uwsm.enable ];

    opts = {
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

    # Would like to disable clearing the TTY but it sometimes causes the issue
    # message to printed over the login prompt
    # systemd.services."getty@".serviceConfig.TTYVTDisallocate = "no";

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
            if test -z $SSH_TTY && uwsm check may-start -q ${optionalString select "&& uwsm select"}; then
              exec uwsm start ${if select then "default" else "-- ${cfg.defaultDesktop}"} >/dev/null
            fi

            # This is needed to ensure that home-manager variables (home.sessionVariables)
            # have precendence over system variables (environment.systemVariables).

            # Explanation:
            # 1. /etc/zshenv sourced -- doesn't do anything important
            # 2. ~/.zshenv sourced
            # Home Manager sources /etc/profiles/per-user/username/etc/profile.d/hm-session-vars.sh
            # which exports all home.sessionVariables and sets EDITOR=nvim. It also sets
            # __HM_SESS_VARS_SOURCED so child shells will not run this again.
            # 3. /etc/zprofile sourced
            # UWSM starts the compositor and saves the login session variables to $XDG_RUNTIME_DIR/uwsm/env_login
            # 4. UWSM pre-loader service runs
            # First it loads the same session variables that existed in the login shell by
            # reading the env_login file. So at this point EDITOR=nvim which is what we
            # want. However the pre-loader then sources /etc/profile which is where NixOS
            # exports all system environment variables. This overrides our Home Manager
            # EDITOR variable to EDITOR=nano.
            # 5. The UWSM pre-loader populates the systemd user environment with exported
            # variables and system variables have precendence over home manager variables.

            # The fix is to source home-manager variables again AFTER NixOS exports the
            # system variables in /etc/profile. __HM_SESS_VARS_SOURCED isn't an issue here
            # because the UWSM pre-loader does not export the variables it loads from
            # env_login.
            ${optionalString home-manager.enable ''
              . "/etc/profiles/per-user/${username}/etc/profile.d/hm-session-vars.sh"
            ''}
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
    assertions = asserts [
      (categoryCfg.displayManager.name == "uwsm" -> config.programs.uwsm.enable)
      "Using UWSM as a display manager requires it to be enabled"
    ];

    nixpkgs.overlays = [
      (final: prev: {
        uwsm = prev.uwsm.overrideAttrs rec {
          version = "0.21.1";
          src = final.fetchFromGitHub {
            owner = "Vladimir-csp";
            repo = "uwsm";
            tag = "v${version}";
            hash = "sha256-12x3IUfo+sl/9XQ2rqifit4P76JGozSA0JLnpwtU8vM=";
          };
        };

        app2unit = addPatches selfPkgs.app2unit [
          (final.substitute {
            src = ../../../../patches/app2unitServiceApps.patch;
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
