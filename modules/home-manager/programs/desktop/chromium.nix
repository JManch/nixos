{ pkgs }:
{
  home.packages = [ pkgs.chromium ];
  ns.desktop.xdg.removeMimeTypePackages = [ pkgs.chromium ];
  ns.persistence.directories = [ ".config/chromium" ];
}
