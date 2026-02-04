{
  lib,
  pkgs,
  args,
  config,
}:
let
  inherit (lib)
    ns
    mkIf
    getExe
    getExe'
    ;
  inherit (config.${ns}.core) home-manager device;
in
{
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = device.type != "laptop";
  };

  ns.userPackages = [
    (lib.${ns}.wrapHyprlandMoveToActive args pkgs.bluetui "bluetui" ''
      --run '
        if [[ $(${getExe' pkgs.bluez "bluetoothctl"} show | ${getExe pkgs.gnugrep} "Powered:" | ${getExe pkgs.gawk} "{print \$2}") == "no" ]]; then
          (${getExe' pkgs.bluez "bluetoothctl"} power on && ${getExe pkgs.libnotify} --transient --urgency=critical -t 5000 "Bluetooth" "Powered on") >/dev/null &
        fi
      '
    '')
    (pkgs.makeDesktopItem {
      name = "bluetui";
      desktopName = "Bluetui";
      genericName = "Bluetooth Manager";
      type = "Application";
      exec = "xdg-terminal-exec --title=bluetui --app-id=bluetui bluetui";
      comment = "Manage bluetooth devices";
      keywords = [ "bluetooth" ];
      categories = [
        "Utility"
        "Settings"
        "ConsoleOnly"
      ];
      startupNotify = false;
    })
  ];

  ns.hm = mkIf home-manager.enable {
    ${ns}.desktop.hyprland.windowRules."bluetui" = lib.${ns}.mkHyprlandCenterFloatRule "bluetui" 60 60;
  };

  ns.persistence.directories = [ "/var/lib/bluetooth" ];
}
