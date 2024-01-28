{ lib, pkgs, config, ... }:
let
  cfg = config.modules.programs.qbittorrent;
in
lib.mkIf cfg.enable
{
  home.packages = [ pkgs.qbittorrent ];

  impermanence.directories = [
    ".config/qBittorrent"
    ".local/share/qBittorrent"
  ];
}
