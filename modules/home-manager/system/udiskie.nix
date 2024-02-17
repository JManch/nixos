{ lib, pkgs, osConfig, ... }:
lib.mkIf osConfig.modules.services.udisks.enable
{
  home.packages = [ pkgs.udiskie ];

  services.udiskie = {
    enable = true;
    automount = true;
    notify = true;
    tray = "never"; # auto tray doesn't work with waybar tray
  };
}
