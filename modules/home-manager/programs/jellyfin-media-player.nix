{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.modules.programs.jellyfin-media-player;
in
lib.mkIf cfg.enable {
  home.packages = [ pkgs.jellyfin-media-player ];

  persistence.directories = [
    ".local/share/jellyfinmediaplayer"
    ".local/share/Jellyfin Media Player"
  ];
}
