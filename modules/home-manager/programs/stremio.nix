{ lib, pkgs, config, ... }:
let
  cfg = config.modules.programs.stremio;
in
lib.mkIf cfg.enable
{
  home.packages = [ pkgs.stremio ];

  persistence.directories = [
    ".local/share/Smart Code ltd"
  ];
}
