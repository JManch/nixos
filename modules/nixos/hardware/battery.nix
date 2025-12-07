{
  lib,
  pkgs,
  config,
}:
let
  inherit (config.${lib.ns}.core) device;
  inherit (config.${lib.ns}.system) desktop;
in
{
  enableOpt = false;
  conditions = [
    (desktop.desktopEnvironment == null)
    (device.battery != null)
    (device.type == "laptop")
  ];

  systemd.user.services.low-battery-notify = {
    requisite = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    path = lib.mkForce [ ]; # inherit user session env vars
    startAt = "*:0/2"; # every 2 mins
    script = ''
      cap=$(cat /sys/class/power_supply/${device.battery}/capacity)
      status=$(cat /sys/class/power_supply/${device.battery}/status)

      if [[ $cap -le 10 && $status == "Discharging" ]]; then
        ${lib.getExe pkgs.libnotify} --urgency=critical -t 5000 "Battery Low" "$cap% remaining";
      fi
    '';
  };
}
