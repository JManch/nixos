{ lib, osConfig, ... }:
let
  inherit (lib) ns;
  inherit (osConfig.${ns}.core) device;
in
{
  enableOpt = false;
  conditions = [
    osConfig.services.upower.enable
    (device.battery != null)
  ];

  services.poweralertd = {
    enable = true;
    extraArgs = [
      "-s"
      "-i"
      "line power"
    ];
  };

  systemd.user.services."poweralertd" = {
    Unit.Requisite = [ "graphical-session.target" ];
    Service.Slice = "background${lib.${ns}.sliceSuffix osConfig}.slice";
  };
}
