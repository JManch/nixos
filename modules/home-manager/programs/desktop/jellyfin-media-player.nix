{ pkgs }:
{
  home.packages = [ pkgs.jellyfin-media-player ];

  nsConfig.persistence.directories = [
    ".local/share/jellyfinmediaplayer"
    ".local/share/Jellyfin Media Player"
  ];
}
