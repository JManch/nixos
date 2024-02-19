{ lib
, pkgs
, config
, osConfig
, ...
}:
let
  inherit (lib) mkIf fetchers getExe;
  osDesktopEnabled = osConfig.usrEnv.desktop.enable;
  isWayland = fetchers.isWayland config;

  swww = getExe pkgs.swww;
  transition =
    let
      primaryMonitor = fetchers.primaryMonitor osConfig;
      refreshRate = "${toString (builtins.floor primaryMonitor.refreshRate)}";
    in
    "--transition-bezier .43,1.19,1,.4 --transition-type center --transition-duration 1 --transition-fps ${refreshRate}";
in
mkIf (osDesktopEnabled && isWayland) {
  home.packages = [ pkgs.swww ];
  modules.desktop.services.wallpaper.setWallpaperCmd = "${swww} img ${transition}";
  wayland.windowManager.hyprland.settings.exec-once = [ "${swww} init --no-cache" ];
}
