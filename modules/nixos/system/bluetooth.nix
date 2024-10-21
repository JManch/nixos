{
  ns,
  lib,
  config,
  ...
}:
let
  inherit (lib) mkIf;
  inherit (config.${ns}.core) homeManager;
  cfg = config.${ns}.system.bluetooth;
in
mkIf cfg.enable {
  hardware.bluetooth.enable = true;
  services.blueman.enable = true;

  hm = mkIf homeManager.enable {
    desktop.hyprland.settings.windowrulev2 = [
      "float, class:^(.blueman-manager-wrapped)$"
      "size 30% 30%, class:^(.blueman-manager-wrapped)$"
      "center, class:^(.blueman-manager-wrapped)$"
    ];
  };

  persistence.directories = [
    "/var/lib/bluetooth"
    "/var/lib/blueman"
  ];
}
