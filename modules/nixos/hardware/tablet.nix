{ lib, config }:
{
  hardware.opentabletdriver.enable = true;

  systemd.user.services.opentabletdriver = {
    after = [ "graphical-session.target" ];
    serviceConfig.Slice = "background${lib.${lib.ns}.sliceSuffix config}.slice";
    serviceConfig.SuccessExitStatus = 143;
  };

  persistenceHome.directories = [ ".config/OpenTabletDriver" ];
}
