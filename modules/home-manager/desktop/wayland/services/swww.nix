{ lib
, pkgs
, config
, nixosConfig
, ...
}:
let
  inherit (lib) mkIf;
  isWayland = lib.fetchers.isWayland config;
  osDesktopEnabled = nixosConfig.usrEnv.desktop.enable;

  swww = "${pkgs.swww}/bin/swww";
  primaryMonitor = lib.fetchers.primaryMonitor nixosConfig;
  refreshRate = "${builtins.toString (builtins.floor primaryMonitor.refreshRate)}";
  transition =
    "--transition-bezier .43,1.19,1,.4 --transition-type center --transition-duration 1 --transition-fps ${refreshRate}";
in
mkIf (osDesktopEnabled && isWayland) {

  home.packages = [ pkgs.swww ];

  modules.desktop.services.wallpaper.setWallpaperCmd = "${swww} img ${transition}";

  wayland.windowManager.hyprland.settings.exec-once =
    mkIf (config.modules.desktop.windowManager == "hyprland")
      [
        "${swww} init --no-cache"
      ];

}
