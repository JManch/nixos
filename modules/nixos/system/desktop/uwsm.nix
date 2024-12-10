{
  lib,
  pkgs,
  config,
  selfPkgs,
  ...
}:
let
  inherit (lib)
    ns
    mkIf
    mkMerge
    mkOrder
    getExe'
    optionalString
    ;
  inherit (cfg.uwsm) defaultDesktop;
  cfg = config.${ns}.system.desktop;
in
mkMerge [
  {
    assertions = lib.${ns}.asserts [
      (cfg.displayManager == "uwsm" -> config.programs.uwsm.enable)
      "Using UWSM as a display manager requires it to be enabled"
    ];
  }

  (mkIf (cfg.enable && config.programs.uwsm.enable) {
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

    # Info on launching a uwsm desktop entry with uwsm start:
    # https://github.com/NixOS/nixpkgs/pull/355416#issuecomment-2481432259
    programs.zsh.interactiveShellInit =
      let
        select = defaultDesktop == null;
      in
      mkIf (cfg.displayManager == "uwsm") (
        mkOrder 2000
          # bash
          ''
            if uwsm check may-start ${optionalString select "&& uwsm select"}; then
              exec systemd-cat -t uwsm-start uwsm start ${if select then "default" else defaultDesktop}
            fi
          ''
      );
  })
]
