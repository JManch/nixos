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
mkIf (cfg.enable && osConfig.usrEnv.desktop.enable && (fetchers.isWayland config))
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
      # TODO: Add --no-cache flag when 0.9.5 releases
      ExecStart = getExe' pkgs.swww "swww-daemon";
    };

    Install.WantedBy = [ "graphical-session.target" ];
  };
}
