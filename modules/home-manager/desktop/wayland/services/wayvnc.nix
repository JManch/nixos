{
  lib,
  pkgs,
  config,
  ...
}:
let
  inherit (lib) ns mkIf getExe';
  cfg = config.${ns}.desktop.services.wayvnc;
in
# TODO: WIP
mkIf false {
  home.packages = [ pkgs.wayvnc ];
  systemd.user.services.wayvnc = {
    Unit = {
      description = "Wayland VNC server";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };

    Service = {
      ExecStart = getExe' pkgs.wayvnc "wayvnc";
      Restart = "on-failure";
      RestartSec = 30;
    };

    Install.WantedBy = [ "graphical-session.target" ];
  };
}
