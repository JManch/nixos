{
  lib,
  pkgs,
  osConfig,
  vmVariant,
  desktopEnabled,
  ...
}:
let
  inherit (lib) ns mkIf mkForce;
  udisks = osConfig.${ns}.services.udisks;
in
mkIf (desktopEnabled && udisks.enable && !vmVariant) {
  assertions = lib.${ns}.asserts [
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
    Service.Slice = [ "background-graphical.slice" ];
  };
}
