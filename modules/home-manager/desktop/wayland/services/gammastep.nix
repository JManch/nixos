{ lib, config, nixosConfig, ... }:
let
  cfg = config.modules.desktop.services.gammastep;
in
lib.mkIf (cfg.enable && nixosConfig.device.gpu.type == "amd")
{
  # We use gammastep instead of wlsunset because wlsunset would often disable
  # itself after using dpms
  services.gammastep = {
    enable = true;
    latitude = "50.8";
    longitude = "-0.1";
    temperature = {
      day = 6500;
      night = 3700;
    };
  };
}
