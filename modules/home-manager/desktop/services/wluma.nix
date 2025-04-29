{ lib, osConfig }:
let
  inherit (lib) ns singleton;
  inherit (lib.${ns}) sliceSuffix;
  inherit (osConfig.${ns}.core.device) primaryMonitor backlight;
in
{
  asserts = [
    (backlight != null)
    "wluma requires the device to have a backlight"
  ];

  services.wluma = {
    enable = true;
    systemd.target = "graphical-session.target";
    settings = {
      als.iio = {
        path = "/sys/bus/iio/devices";
        thresholds = {
          "0" = "night";
          "20" = "dark";
          "80" = "dim";
          "250" = "normal";
          "500" = "bright";
          "800" = "outdoors";
        };
      };

      output.backlight = singleton {
        name = "${primaryMonitor.name}";
        path = "/sys/class/backlight/${backlight}";
        capturer = "none";
      };
    };
  };

  systemd.user.services.wluma.Service.Slice = "background${sliceSuffix osConfig}.slice";

  ns.persistence.directories = [ ".local/share/wluma" ];
}
