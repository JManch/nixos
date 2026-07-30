{ pkgs }:
{
  home.packages = [ pkgs.tor-browser ];

  # maximizes on launch for some reason
  ns.desktop.hyprland.extraConf = # lua
    ''
      hl.window_rule({ match = { class = "Tor Browser" }, suppress_event = "maximize" })
    '';
}
