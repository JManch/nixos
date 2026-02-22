{
  lib,
  pkgs,
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
    (pkgs.symlinkJoin {
      name = "bluetui-wrapped";
      paths = [ pkgs.bluetui ];
      nativeBuildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        wrapProgram $out/bin/bluetui --run '
          if [[ $(${getExe' pkgs.bluez "bluetoothctl"} show | ${getExe pkgs.gnugrep} "Powered:" | ${getExe pkgs.gawk} "{print \$2}") == "no" ]]; then
            (${getExe' pkgs.bluez "bluetoothctl"} power on && ${getExe pkgs.libnotify} --transient --urgency=critical -t 5000 "Bluetooth" "Powered on") >/dev/null &
          fi
        '
      '';
    })
    (pkgs.makeDesktopItem {
      name = "bluetui";
      desktopName = "Bluetui";
      genericName = "Bluetooth Manager";
      type = "Application";
      icon = "preferences-bluetooth";
      exec = "${pkgs.writeShellScript "bluetui-desktop-launch" ''
        address=$(hyprctl clients -j | ${getExe pkgs.jaq} -r "(.[] | select(.class == \"bluetui\")) | .address")
        if [[ -n $address ]]; then
          hyprctl dispatch movetoworkspacesilent e+0, address:"$address"
          exit 0
        fi
        xdg-terminal-exec --title=bluetui --app-id=bluetui bluetui
      ''}";
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
