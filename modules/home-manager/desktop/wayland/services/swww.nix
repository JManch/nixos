{ lib
, pkgs
, config
, osConfig
, ...
}:
let
  inherit (lib) mkIf fetchers getExe getExe';
  cfg = config.modules.desktop.programs.swww;
  transition =
    let
      primaryMonitor = fetchers.primaryMonitor osConfig;
      refreshRate = toString (builtins.floor primaryMonitor.refreshRate);
    in
    "--transition-bezier .43,1.19,1,.4 --transition-type center --transition-duration 1 --transition-fps ${refreshRate}";
in
mkIf (cfg.enable && osConfig.modules.system.desktop.enable && (fetchers.isWayland osConfig config))
{
  modules.desktop.services.wallpaper.setWallpaperCmd = "${getExe pkgs.swww} img ${transition}";

  systemd.user.services.swww = {
    Unit = {
      Description = "Animated wallpaper daemon";
      Before = [ "set-wallpaper.service" ];
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session-pre.target" ];
    };

    Service = {
      ExecStart = "${getExe' pkgs.swww "swww-daemon"} --no-cache";
    };

    Install.WantedBy = [ "graphical-session.target" ];
  };

  modules.desktop.services.wallpaper.dependencyUnit = "swww.service";
}
