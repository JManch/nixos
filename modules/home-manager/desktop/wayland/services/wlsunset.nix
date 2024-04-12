{ lib, config, osConfig, ... }:
let
  cfg = config.modules.desktop.services.wlsunset;
in
lib.mkIf (cfg.enable && osConfig.device.gpu.type == "amd")
{
  # WARN: Wlsunset (or any other gamma adjuster) will cause system audio to
  # stutter during gamma adjustments if audio is coming from monitors. This
  # includes using the headphone jack on a monitor.
  services.wlsunset = {
    enable = true;
    latitude = "50.8";
    longitude = "-0.1";

    temperature = {
      day = 6500;
      night = 4000;
    };
  };
}
