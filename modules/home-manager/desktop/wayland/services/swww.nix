{
  lib,
  pkgs,
  config,
  osConfig,
  isWayland,
  ...
}:
let
  inherit (lib)
    ns
    mkIf
    getExe
    getExe'
    ;
  cfg = config.${ns}.desktop.programs.swww;
  transition =
    let
      inherit (osConfig.${ns}.device) primaryMonitor;
      refreshRate = toString (builtins.floor primaryMonitor.refreshRate);
    in
    "--transition-bezier .43,1.19,1,.4 --transition-type center --transition-duration 1 --transition-fps ${refreshRate}";
in
mkIf (cfg.enable && isWayland) {
  ${ns}.desktop.services.wallpaper = {
    setWallpaperCmd = "${getExe pkgs.swww} img ${transition}";
    wallpaperUnit = "swww.service";
  };

  systemd.user.services.swww = {
    Unit = {
      Description = "Animated wallpaper daemon";
      Before = [ "set-wallpaper.service" ];
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };

    Service = {
      Slice = "background${lib.${ns}.sliceSuffix osConfig}.slice";
      ExecStart = "${getExe' pkgs.swww "swww-daemon"} --quiet --no-cache";
    };

    Install.WantedBy = [ "graphical-session.target" ];
  };
}
