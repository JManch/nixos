{ lib
, pkgs
, config
, osConfig
, ...
}:
let
  inherit (lib) mkIf fetchers getExe;
  cfg = config.modules.desktop.programs.swww;
  swww = getExe pkgs.swww;

  transition =
    let
      primaryMonitor = fetchers.primaryMonitor osConfig;
      refreshRate = toString (builtins.floor primaryMonitor.refreshRate);
    in
    "--transition-bezier .43,1.19,1,.4 --transition-type center --transition-duration 1 --transition-fps ${refreshRate}";
in
mkIf (cfg.enable && osConfig.usrEnv.desktop.enable && (fetchers.isWayland config))
{
  modules.desktop.services.wallpaper.setWallpaperCmd = "${swww} img ${transition}";
  wayland.windowManager.hyprland.settings.exec-once = [ "${swww} init --no-cache" ];
}
