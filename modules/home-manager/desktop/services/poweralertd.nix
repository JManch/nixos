{ lib, osConfig, ... }:
let
  inherit (osConfig.${lib.ns}.core) device;
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
      "-S"
    ];
  };
}
