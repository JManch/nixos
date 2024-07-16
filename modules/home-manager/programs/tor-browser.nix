{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.modules.programs.torBrowser;
in
lib.mkIf cfg.enable { home.packages = [ pkgs.tor-browser ]; }
