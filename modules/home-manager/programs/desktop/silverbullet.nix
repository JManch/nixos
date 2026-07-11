{ lib, pkgs }:
{
  home.packages = [ pkgs.${lib.ns}.silverbullet-app ];
}
