{
  lib,
  pkgs,
  osConfig,
}:
let
  inherit (lib) ns getExe getExe';
  inherit (osConfig.${ns}.core.device) monitors;
  transition =
    let
      inherit (osConfig.${ns}.core) device;
      refreshRate = toString (builtins.floor device.primaryMonitor.refreshRate);
    in
    "--transition-bezier .43,1.19,1,.4 --transition-type center --transition-duration 1 --transition-fps ${refreshRate}";
in
{
  asserts = [
    (lib.all (monitor: monitor.scale == 1) monitors)
    "awww doesn't work for monitors with scale != 1 as it requires `awww img` to be called twice for the wallpaper to set after boot"
  ];

  categoryConfig.wallpaper = {
    wallpaperUnit = "awww.service";
    setWallpaperScript = "${getExe pkgs.awww} img ${transition} \"$1\"";
  };

  systemd.user.services.awww = {
    Unit = {
      Description = "Awww Wallpaper Daemon";
      Before = [ "set-wallpaper.service" ];
      PartOf = [ "graphical-session.target" ];
      Requisite = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };

    Service = {
      Slice = "background${lib.${ns}.sliceSuffix osConfig}.slice";
      ExecStart = "${getExe' pkgs.awww "awww-daemon"} --quiet --no-cache";
    };

    Install.WantedBy = [ "graphical-session.target" ];
  };
}
