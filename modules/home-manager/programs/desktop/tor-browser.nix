{ pkgs }:
{
  home.packages = [ pkgs.tor-browser ];

  # maximizes on launch for some reason
  ns.desktop.hyprland.settings.windowrule = [
    "match:class Tor Browser, suppress_event maximize"
  ];
}
