{ lib, osConfig, ... }:
lib.mkIf osConfig.modules.services.udisks.enable
{
  services.udiskie = {
    enable = true;
    automount = true;
    notify = true;
    tray = "auto";
  };
}
