{ lib, pkgs, config, ... }:
let
  cfg = config.modules.programs.gaming.r2modman;
in
lib.mkIf cfg.enable
{
  home.packages = [ pkgs.r2modman ];

  impermanence.directories = [
    ".config/r2modman"
  ];
}
