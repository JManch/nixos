{ pkgs }:
{
  home.packages = [ pkgs.r2modman ];
  ns.persistence.directories = [ ".config/r2modman" ];
}
