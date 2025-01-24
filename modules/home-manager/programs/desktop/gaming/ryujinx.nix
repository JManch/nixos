{ pkgs }:
{
  home.packages = [ pkgs.ryujinx ];
  nsConfig.persistence.directories = [ ".config/Ryujinx" ];
}
