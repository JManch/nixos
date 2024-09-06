{
  ns,
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.${ns}.programs.torBrowser;
in
lib.mkIf cfg.enable { home.packages = [ pkgs.tor-browser ]; }
