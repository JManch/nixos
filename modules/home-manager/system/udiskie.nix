{ lib
, pkgs
, osConfig
, vmVariant
, ...
}:
lib.mkIf (osConfig.modules.services.udisks.enable && !vmVariant)
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
