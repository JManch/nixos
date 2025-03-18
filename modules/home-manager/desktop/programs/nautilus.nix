{ pkgs }:
{
  enableOpt = false;
  home.packages = [ pkgs.nautilus ];

  ns.desktop.hyprland.settings.windowrule = [
    "float, class:^(org.gnome.Nautilus)$"
    "size 50% 50%, class:^(org.gnome.Nautilus)$"
    "center, class:^(org.gnome.Nautilus)$"
  ];
}
