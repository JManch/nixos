{
  lib,
  pkgs,
  config,
  osConfig',
  isWayland,
  ...
}:
let
  inherit (lib) mkIf getExe getExe';
  cfg = config.modules.desktop.programs.swww;
  transition =
    let
      inherit (osConfig'.device) primaryMonitor;
      refreshRate = toString (builtins.floor primaryMonitor.refreshRate);
    in
    "--transition-bezier .43,1.19,1,.4 --transition-type center --transition-duration 1 --transition-fps ${refreshRate}";
in
mkIf (cfg.enable && isWayland) {
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
