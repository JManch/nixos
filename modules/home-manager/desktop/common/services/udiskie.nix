{ lib
, pkgs
, osConfig'
, vmVariant
, desktopEnabled
, ...
}:
let
  udisks = osConfig'.modules.services.udisks;
in
lib.mkIf (desktopEnabled && udisks.enable && !vmVariant)
{
  assertions = lib.utils.asserts [
    (osConfig'.modules.system.desktop.desktopEnvironment == null)
    "udiskie should not need to be enabled with a desktop environment"
  ];

  # Use `udiskie-umount -a` to unmount all
  home.packages = [ pkgs.udiskie ];

  services.udiskie = {
    enable = true;
    automount = true;
    notify = true;
    tray = "never"; # auto tray doesn't work with waybar tray
  };
}
