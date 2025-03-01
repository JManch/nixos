{ pkgs }:
{
  home.packages = [ pkgs.stremio ];
  ns.persistence.directories = [ ".local/share/Smart Code ltd" ];
}
