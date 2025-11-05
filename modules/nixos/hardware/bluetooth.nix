{
  lib,
  pkgs,
  config,
}:
let
  inherit (lib) ns mkIf;
  inherit (config.${ns}.core) home-manager device;
in
{
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = device.type != "laptop";
  };

  ns.userPackages = [ pkgs.bluetui ];

  ns.hm = mkIf home-manager.enable {
    xdg.desktopEntries.bluetui = mkIf config.${ns}.hmNs.desktop.enable {
      name = "bluetui";
      genericName = "Bluetooth Manager";
      exec = "xdg-terminal-exec --title=bluetui --app-id=bluetui bluetui";
      terminal = false;
      type = "Application";
      icon = "application-x-generic";
      categories = [ "System" ];
    };

    ${ns}.desktop.hyprland.settings.windowrule = [
      "float, class:^(bluetui)$"
      "size 60% 50%, class:^(bluetui)$"
      "center, class:^(bluetui)$"
    ];
  };

  ns.persistence.directories = [ "/var/lib/bluetooth" ];
}
