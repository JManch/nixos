{
  lib,
  pkgs,
  osConfig,
  vmVariant,
}:
let
  inherit (lib) ns mkForce;
in
{
  enableOpt = false;
  conditions = [
    "osConfigStrict.services.udisks"
    (vmVariant == false || vmVariant == null)
  ];

  asserts = [
    (osConfig.${ns}.system.desktop.desktopEnvironment == null)
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

  systemd.user.services.udiskie = {
    Unit.After = mkForce [ "graphical-session.target" ];
    Service.Slice = "background${lib.${ns}.sliceSuffix osConfig}.slice";
  };
}
