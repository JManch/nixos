{
  lib,
  pkgs,
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
    getExe'
    replaceStrings
    optionalString
    ;
  inherit (lib.${ns}) asserts;
  inherit (cfg.uwsm) defaultDesktop;
  cfg = config.${ns}.system.desktop;
in
mkMerge [
  {
    assertions = asserts [
      (cfg.displayManager == "uwsm" -> config.programs.uwsm.enable)
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
      path = [ pkgs.libnotify ];
      serviceConfig.ExecStart = [
        "" # to replace original ExecStart
        (getExe' config.programs.uwsm.package "fumon")
      ];
    };

    services.getty = {
      # Automatically populate with primary user whilst still prompting for
      # password
      loginOptions = username;
      extraArgs = [
        "--skip-login"
        "--noclear"
      ];
    };

    # Do not clear the TTY
    systemd.services."getty@".serviceConfig.TTYVTDisallocate = "no";

    # Remove excess new lines and use normal green instead of bright
    environment.etc.issue.source = pkgs.writeText "issue" ''
      [0;32m${replaceStrings [ "<<< " " >>>" ] [ "" "" ] config.services.getty.greetingLine}[0m
    '';

    security.loginDefs.settings = {
      # Disable timeout as with --skip-login the default timeout of 60 seconds
      # causes it to repeatedly timeout indefinitely
      LOGIN_TIMEOUT = 0;
    };

    programs.zsh.interactiveShellInit =
      let
        select = defaultDesktop == null;
      in
      mkIf (cfg.displayManager == "uwsm") (
        mkOrder 2000
          # bash
          ''
            if uwsm check may-start ${optionalString select "&& uwsm select"}; then
              exec uwsm start -S ${if select then "default" else "-- ${defaultDesktop}"} >/dev/null
            fi
          ''
      );
  })
]
