{ lib, pkgs, config, ... }:
let
  inherit (lib) mkIf getExe';
  cfg = config.modules.desktop.services.wayvnc;
in
# TODO: WIP
mkIf false
{
  home.packages = [ pkgs.wayvnc ];
  systemd.user.services.wayvnc = {
    Unit = {
      description = "Wayland VNC server";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session-pre.target" ];
    };

    Service = {
      ExecStart = getExe' pkgs.wayvnc "wayvnc";
      Restart = "on-failure";
      RestartSec = "30";
    };

    Install.WantedBy = [ "graphical-session.target" ];
  };
}
