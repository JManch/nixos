{ pkgs }:
{
  home.packages = [ pkgs.filen-desktop ];
  ns.persistence.directories = [ ".config/filen-desktop" ];
}
