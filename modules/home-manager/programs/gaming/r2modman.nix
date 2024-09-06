{
  ns,
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.${ns}.programs.gaming.r2modman;
in
lib.mkIf cfg.enable {
  home.packages = [ pkgs.r2modman ];

  persistence.directories = [ ".config/r2modman" ];
}
