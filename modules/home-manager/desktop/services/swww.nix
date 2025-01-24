{
  lib,
  pkgs,
  osConfig,
}:
let
  inherit (lib) ns getExe getExe';
  transition =
    let
      inherit (osConfig.${ns}.device) primaryMonitor;
      refreshRate = toString (builtins.floor primaryMonitor.refreshRate);
    in
    "--transition-bezier .43,1.19,1,.4 --transition-type center --transition-duration 1 --transition-fps ${refreshRate}";
in
{
  categoryConfig.wallpaper = {
    wallpaperUnit = "swww.service";
    setWallpaperScript = "${getExe pkgs.swww} img ${transition} \"$1\"";
  };

  systemd.user.services.swww = {
    Unit = {
      Description = "Swww Wallpaper Daemon";
      Before = [ "set-wallpaper.service" ];
      PartOf = [ "graphical-session.target" ];
      Requires = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };

    Service = {
      Slice = "background${lib.${ns}.sliceSuffix osConfig}.slice";
      ExecStart = "${getExe' pkgs.swww "swww-daemon"} --quiet --no-cache";
    };

    Install.WantedBy = [ "graphical-session.target" ];
  };
}
