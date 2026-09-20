{ lib, pkgs }:
{
  home.packages = [ pkgs.${lib.ns}.silverbullet-app ];
  ns.desktop.xdg.removeMimeTypePackages = [ pkgs.${lib.ns}.silverbullet-app ];

  # SilverBullet attempts to install its own .desktop file for link handling
  xdg.dataFile."applications/silverbullet-app.desktop" = {
    source = "${pkgs.${lib.ns}.silverbullet-app}/share/applications/silverbullet-app.desktop";
    force = true;
  };
}
