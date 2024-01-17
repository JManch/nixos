{ lib, pkgs, config, ... }:
let
  cfg = config.modules.programs.stremio;
in
lib.mkIf cfg.enable {
  home.packages = [ pkgs.stremio ];

  impermanence.directories = [
    ".local/share/Smart Code ltd"
    ".stremio-server" # Cache is stored here
  ];
}
