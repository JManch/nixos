{ pkgs }:
{
  enableOpt = false;
  home.packages = [ pkgs.nautilus ];

  dconf.settings."org/gnome/nautilus/preferences".default-folder-viewer = "list-view";

  ns.desktop.hyprland.windowRules = {
    "nautilus-float" = {
      matchers.class = "org\\.gnome\\.Nautilus";
      params.float = true;
    };

    "nautilus-resize" = {
      matchers.class = "org\\.gnome\\.Nautilus";
      matchers.title = "negative:Properties";
      params.size = "monitor_w*0.6 monitor_h*0.6";
      params.center = true;
    };
  };
}
