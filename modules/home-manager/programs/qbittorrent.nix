{
  ns,
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.${ns}.programs.qbittorrent;
in
lib.mkIf cfg.enable {
  home.packages = [ pkgs.qbittorrent ];

  persistence.directories = [
    ".config/qBittorrent"
    ".local/share/qBittorrent"
  ];
}
