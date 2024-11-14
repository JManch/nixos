{
  ns,
  lib,
  pkgs,
  config,
  ...
}:
let
  inherit (lib)
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
    systemd.user.services.fumon = {
      wantedBy = [ "graphical-session.target" ];
      path = [ pkgs.libnotify ];
      serviceConfig.ExecStart = [
        "" # to replace original ExecStart
        (getExe' config.programs.uwsm.package "fumon")
      ];
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
              exec systemd-cat -t uwsm_start uwsm start ${if select then "default" else defaultDesktop}
            fi
          ''
      );
  })
]
