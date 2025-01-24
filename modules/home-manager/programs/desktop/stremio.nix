{ pkgs }:
{
  home.packages = [ pkgs.stremio ];
  nsConfig.persistence.directories = [ ".local/share/Smart Code ltd" ];
}
