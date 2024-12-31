{ lib, config, ... }:
let
  inherit (lib) ns mkIf;
  cfg = config.${ns}.hardware.tablet;
in
mkIf cfg.enable {
  hardware.opentabletdriver.enable = true;

  systemd.user.services.opentabletdriver = {
    after = [ "graphical-session.target" ];
    serviceConfig.Slice = "background${lib.${ns}.sliceSuffix config}.slice";
  };

  persistenceHome.directories = [ ".config/OpenTabletDriver" ];
}
