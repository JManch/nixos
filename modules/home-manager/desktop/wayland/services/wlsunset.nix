{ lib, config, osConfig, ... }:
let
  cfg = config.modules.desktop.services.wlsunset;
in
lib.mkIf (cfg.enable && osConfig.device.gpu.type == "amd")
{
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
