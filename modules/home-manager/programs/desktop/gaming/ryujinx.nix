{ pkgs }:
{
  home.packages = [ pkgs.ryujinx ];
  ns.persistence.directories = [ ".config/Ryujinx" ];
}
