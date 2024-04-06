{ lib
, pkgs
, osConfig
, vmVariant
, ...
}:
let
  udisks = osConfig.modules.services.udisks;
  osDesktop = osConfig.usrEnv.desktop;
in
lib.mkIf (osDesktop.enable && udisks.enable && !vmVariant)
{
  # Use `udiskie-umount -a` to unmount all
  home.packages = [ pkgs.udiskie ];

  services.udiskie = {
    enable = true;
    automount = true;
    notify = true;
    tray = "never"; # auto tray doesn't work with waybar tray
  };
}
