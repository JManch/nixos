{
  lib,
  pkgs,
  desktopEnabled,
  ...
}:
lib.mkIf desktopEnabled {
  home.packages = [ pkgs.nautilus ];

  desktop.hyprland.settings.windowrulev2 = [
    "float, class:^(org.gnome.Nautilus)$"
    "size 50% 50%, class:^(org.gnome.Nautilus)$"
    "center, class:^(org.gnome.Nautilus)$"
  ];
}
