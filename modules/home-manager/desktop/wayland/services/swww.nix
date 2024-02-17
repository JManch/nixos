{ lib
, pkgs
, config
, osConfig
, ...
}:
let
  inherit (lib) mkIf;
  isWayland = lib.fetchers.isWayland config;
  osDesktopEnabled = osConfig.usrEnv.desktop.enable;

  swww = "${pkgs.swww}/bin/swww";
  primaryMonitor = lib.fetchers.primaryMonitor osConfig;
  refreshRate = "${toString (builtins.floor primaryMonitor.refreshRate)}";
  transition =
    "--transition-bezier .43,1.19,1,.4 --transition-type center --transition-duration 1 --transition-fps ${refreshRate}";
in
mkIf (osDesktopEnabled && isWayland) {

  home.packages = [ pkgs.swww ];

  modules.desktop.services.wallpaper.setWallpaperCmd = "${swww} img ${transition}";

  wayland.windowManager.hyprland.settings.exec-once =
    mkIf (config.modules.desktop.windowManager == "Hyprland")
      [
        "${swww} init --no-cache"
      ];

}
