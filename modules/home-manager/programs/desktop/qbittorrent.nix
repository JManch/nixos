{ pkgs }:
{
  home.packages = [ pkgs.qbittorrent ];

  nsConfig.persistence.directories = [
    ".config/qBittorrent"
    ".local/share/qBittorrent"
  ];
}
