{
  lib,
  config,
  selfPkgs,
  username,
  ...
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
    optionalString
    ;
  inherit (config.${ns}.core) homeManager;
  inherit (lib.${ns}) asserts;
  inherit (cfg.uwsm) defaultDesktop;
  cfg = config.${ns}.system.desktop;
in
mkMerge [
  {
    assertions = asserts [
      (cfg.displayManager.name == "uwsm" -> config.programs.uwsm.enable)
      "Using UWSM as a display manager requires it to be enabled"
    ];

    nixpkgs.overlays = [
      (final: prev: {
        uwsm = prev.uwsm.overrideAttrs {
          version = "git";
          src = final.fetchFromGitHub {
            owner = "Vladimir-csp";
            repo = "uwsm";
            rev = "ec9a72cd00726c7333663c9324df13f420094fd1";
            hash = "sha256-JqF3v00M+HOQzNWbMq4/6GfoVA4OwrONEvXLVLr0vec=";
          };
        };
      })
    ];
  }

  (mkIf (cfg.enable && config.programs.uwsm.enable) {
    assertions = asserts [
      # Seems ok to nest UWSM start calls by using a UWSM desktop entry but we
      # should prefer to avoid it
      # https://github.com/NixOS/nixpkgs/pull/355416#issuecomment-2481432259
      (defaultDesktop != null -> !hasInfix "uwsm" defaultDesktop)
      ''
        The UWSM default desktop entry should not be a UWSM variant. Use the
        default non-UWSM desktop entry instead.
      ''
    ];

    environment = {
      systemPackages = [ selfPkgs.app2unit ];
      sessionVariables.APP2UNIT_SLICES = "a=app-graphical.slice b=background-graphical.slice s=session-graphical.slice";
      sessionVariables.APP2UNIT_TYPE = "scope";
    };

    systemd.user.services.fumon = {
      wantedBy = [ "graphical-session.target" ];
      path = mkForce [ ]; # reason explained in desktop/default.nix
      serviceConfig.ExecStart = [
        "" # to replace original ExecStart
        (getExe' config.programs.uwsm.package "fumon")
      ];
    };

    services.getty = mkMerge [
      (mkIf (!cfg.displayManager.autoLogin) {
        # Automatically populate with primary user whilst still prompting for
        # password
        loginOptions = username;
        extraArgs = [
          "--skip-login"
          "--noclear"
        ];
      })

      (mkIf cfg.displayManager.autoLogin {
        autologinUser = username;
        autologinOnce = true;
      })
    ];

    # Do not clear the TTY
    systemd.services."getty@".serviceConfig.TTYVTDisallocate = "no";

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
        select = defaultDesktop == null;
      in
      mkIf (cfg.displayManager.name == "uwsm") (
        mkOrder 2000
          # bash
          ''
            if test -z $SSH_TTY && uwsm check may-start -q ${optionalString select "&& uwsm select"}; then
              # Home Manager sets session variables in ~/zshenv and sets
              # __HM_SESS_VARS_SOURCED to ensure that variables are only set once. The
              # problem with this is that ~/zshenv runs before we start UWSM in
              # /etc/zprofile. Therefore if the same variable is set in
              # environment.systemVariables and home.sessionVariables, UWSM will override
              # the home variable with the system variable and, because of
              # __HM_SESS_VARS_SOURCED, the home-manager variable will never be set again. We
              # want home variables to have higher precendence than system variables so the
              # fix is to unset __HM_SESS_VARS_SOURCED before launching UWSM. This way Home
              # Manager variables will be set in every new shell our user makes which is
              # in-line with the behaviour of launching UWSM with a display manager like
              # greetd.

              # We could also solve the problem by launching UWSM in /etc/zshenv
              # (environment.shellInit) but it's not really what zshenv is meant for and
              # running uwsm check in every single shell does not seem ideal.
              ${optionalString homeManager.enable "unset __HM_SESS_VARS_SOURCED"}
              exec uwsm start -S ${if select then "default" else "-- ${defaultDesktop}"} >/dev/null
            fi
          ''
      );
  })
]
