{ pkgs }:
{
  home.packages = [ pkgs.chromium ];

  ns.persistence.directories = [ ".config/chromium" ];
}
