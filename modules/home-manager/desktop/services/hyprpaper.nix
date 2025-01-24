{
  lib,
  pkgs,
  args,
  osConfig,
}:
let
  inherit (lib) ns getExe getExe';
  hyprctl = getExe' pkgs.hyprland "hyprctl";
in
{
  categoryConfig.wallpaper = {
    wallpaperUnit = "hyprpaper.service";
    setWallpaperScript = ''
      ${hyprctl} hyprpaper preload "$1"
      ${hyprctl} hyprpaper wallpaper ",$1"
      ${hyprctl} hyprpaper unload unused
    '';
  };

  # Hyprpaper needs a config file otherwise it core dumps
  xdg.configFile."hypr/hyprpaper.conf".text = ''
    ipc=true
  '';

  systemd.user.services.hyprpaper = {
    Unit = {
      Description = "Hyprpaper Wallpaper Daemon";
      Before = [ "set-wallpaper.service" ];
      PartOf = [ "graphical-session.target" ];
      Requires = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };

    Service = {
      Slice = "background${lib.${ns}.sliceSuffix osConfig}.slice";
      ExecStart = getExe (lib.${ns}.flakePkgs args "hyprpaper").default;
    };

    Install.WantedBy = [ "graphical-session.target" ];
  };
}
