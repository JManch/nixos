{ pkgs }:
{
  enableOpt = false;
  home.packages = [ pkgs.nautilus ];

  ns.desktop.hyprland.settings.windowrulev2 = [
    "float, class:^(org.gnome.Nautilus)$"
    "size 50% 50%, class:^(org.gnome.Nautilus)$"
    "center, class:^(org.gnome.Nautilus)$"
  ];
}
