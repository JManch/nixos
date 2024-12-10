{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.${lib.ns}.programs.torBrowser;
in
lib.mkIf cfg.enable { home.packages = [ pkgs.tor-browser ]; }
