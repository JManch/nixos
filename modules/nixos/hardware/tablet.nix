{ lib, config }:
{
  hardware.opentabletdriver.enable = true;

  systemd.user.services.opentabletdriver = {
    after = [ "graphical-session.target" ];
    requisite = [ "graphical-session.target" ];
    serviceConfig.Slice = "background${lib.${lib.ns}.sliceSuffix config}.slice";
    serviceConfig.SuccessExitStatus = 143;
  };

  ns.persistenceHome.directories = [ ".config/OpenTabletDriver" ];
}
