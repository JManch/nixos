{
  lib,
  pkgs,
  osConfig,
}:
{
  enableOpt = false;
  conditions = [ (osConfig.${lib.ns}.system.desktop.desktopEnvironment == null) ];

  home.packages = [ pkgs.nautilus ];

  dconf.settings."org/gnome/nautilus/preferences".default-folder-viewer = "list-view";

  ns.desktop.hyprland.windowRules = {
    "nautilus-float" = {
      match.class = "org\\.gnome\\.Nautilus";
      float = true;
    };

    "nautilus-resize" = {
      match.class = "org\\.gnome\\.Nautilus";
      match.title = "negative:Properties";
      size = "monitor_w*0.6 monitor_h*0.6";
      center = true;
    };
  };
}
