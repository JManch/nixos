{ pkgs }:
{
  home.packages = [ pkgs.r2modman ];
  nsConfig.persistence.directories = [ ".config/r2modman" ];
}
