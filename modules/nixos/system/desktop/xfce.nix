{ lib, config, ... }:
let
  inherit (lib) mkIf;
  cfg = config.modules.system.desktop;
in
mkIf (cfg.enable && cfg.desktopEnvironment == "xfce") {
  services.xserver = {
    enable = true;
    desktopManager.xfce.enable = true;
  };

  services.displayManager.defaultSession = "xfce";
}
