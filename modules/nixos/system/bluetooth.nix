{ lib, config, ... }:
let
  cfg = config.modules.system.bluetooth;
in
lib.mkIf cfg.enable
{
  hardware.bluetooth.enable = true;
  services.blueman.enable = true;

  persistence.directories = [
    "/var/lib/bluetooth"
    "/var/lib/blueman"
  ];
}
