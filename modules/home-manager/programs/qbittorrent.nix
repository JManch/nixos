{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.${lib.ns}.programs.qbittorrent;
in
lib.mkIf cfg.enable {
  home.packages = [ pkgs.qbittorrent ];

  persistence.directories = [
    ".config/qBittorrent"
    ".local/share/qBittorrent"
  ];
}
