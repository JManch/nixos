{
  ns,
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.${ns}.programs.stremio;
in
lib.mkIf cfg.enable {
  home.packages = [ pkgs.stremio ];

  persistence.directories = [ ".local/share/Smart Code ltd" ];
}
