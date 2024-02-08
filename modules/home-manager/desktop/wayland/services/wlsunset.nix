{ lib, config, osConfig, ... }:
let
  cfg = config.modules.desktop.services.wlsunset;
in
lib.mkIf (cfg.enable && osConfig.device.gpu.type == "amd")
{
  # FIX: Find out why wlsunset randomly disables itself. I suspect it's due to
  # dpms. Gammastep is not an option because it causes stuttering.
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
