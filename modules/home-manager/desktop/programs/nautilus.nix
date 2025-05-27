{ pkgs }:
{
  enableOpt = false;
  home.packages = [ pkgs.nautilus ];

  dconf.settings."org/gnome/nautilus/preferences".default-folder-viewer = "list-view";

  ns.desktop.hyprland.settings.windowrule = [
    "float, class:^(org.gnome.Nautilus)$"
    "size 60% 60%, class:^(org.gnome.Nautilus)$, title:negative:Properties"
    "center, class:^(org.gnome.Nautilus)$, title:negative:Properties"
  ];
}
