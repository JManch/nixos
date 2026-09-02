{ lib, pkgs }:
{
  home.packages = [ pkgs.${lib.ns}.silverbullet-app ];
  ns.desktop.xdg.removeMimeTypePackages = [ pkgs.${lib.ns}.silverbullet-app ];
}
