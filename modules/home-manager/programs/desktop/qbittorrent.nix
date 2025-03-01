{ pkgs }:
{
  home.packages = [ pkgs.qbittorrent ];

  ns.persistence.directories = [
    ".config/qBittorrent"
    ".local/share/qBittorrent"
  ];
}
