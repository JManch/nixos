# This module is purely for using UWSM as a display manager. UWSM itself should
# be enabled and setup on a per-desktop basis.
{
  ns,
  lib,
  config,
  ...
}:
let
  inherit (lib) mkIf mkOrder optionalString;
  inherit (cfg.uwsm) defaultDesktop;
  cfg = config.${ns}.system.desktop;
  select = defaultDesktop == null;
in
mkIf (cfg.enable && (cfg.displayManager == "uwsm")) {
  assertions = lib.${ns}.asserts [
    config.programs.uwsm.enable
    "Using UWSM as a display manager requires it to be enabled"
  ];

  programs.zsh.interactiveShellInit =
    mkOrder 2000
      # bash
      ''
        if uwsm check may-start ${optionalString select "&& uwsm select"}; then
          exec systemd-cat -t uwsm_start uwsm start ${if select then "default" else defaultDesktop}
        fi
      '';
}
