{ pkgs }:
{
  home.packages = [ pkgs.chromium ];
  nsConfig.persistence.directories = [ ".config/chromium" ];
}
