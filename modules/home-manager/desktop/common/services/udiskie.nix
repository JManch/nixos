{ lib
, pkgs
, osConfig
, vmVariant
, ...
}:
let
  udisksEnabled = osConfig.modules.services.udisks.enable;
  osDesktopEnabled = osConfig.usrEnv.desktop.enable;
in
lib.mkIf (osDesktopEnabled && udisksEnabled && !vmVariant)
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
