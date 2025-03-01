{ pkgs }:
{
  home.packages = [ pkgs.jellyfin-media-player ];

  ns.persistence.directories = [
    ".local/share/jellyfinmediaplayer"
    ".local/share/Jellyfin Media Player"
  ];
}
