{ lib, config, ... }:
let
  cfg = config.${lib.ns}.hardware.tablet;
in
lib.mkIf cfg.enable {
  hardware.opentabletdriver.enable = true;

  systemd.user.services.opentabletdriver.after = [ "graphical-session.target" ];

  persistenceHome.directories = [
    ".config/OpenTabletDriver"
  ];
}
