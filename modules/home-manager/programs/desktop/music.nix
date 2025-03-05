{ pkgs }:
{
  home.packages = with pkgs; [
    picard
    spek
  ];

  ns.desktop.hyprland.settings.windowrulev2 = [
    "float, class:^(spek)$"
  ];
}
