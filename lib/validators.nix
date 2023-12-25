{lib, ...}: {
  isWayland = config: config.home.desktop.compositor == "hyprland";
}
