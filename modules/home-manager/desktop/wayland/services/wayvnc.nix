{
  ns,
  lib,
  pkgs,
  config,
  ...
}:
let
  inherit (lib) mkIf;
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
      ExecStart = "wayvnc";
      Restart = "on-failure";
      RestartSec = 30;
    };

    Install.WantedBy = [ "graphical-session.target" ];
  };
}
