{ pkgs }:
{
  home.packages = with pkgs; [
    picard
    spek
  ];

  ns.desktop.hyprland.settings.windowrule = [
    "float, class:^(spek)$"
  ];
}
