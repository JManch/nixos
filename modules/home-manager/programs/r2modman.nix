{ lib, pkgs, config, ... }:
let
  cfg = config.modules.programs.r2modman;
in
lib.mkIf cfg.enable
{
  home.packages = [ pkgs.r2modman ];

  persistence.directories = [ ".config/r2modman" ];
}
