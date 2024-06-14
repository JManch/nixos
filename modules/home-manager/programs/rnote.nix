{ lib, pkgs, config, ... }:
let
  cfg = config.modules.programs.rnote;
in
lib.mkIf cfg.enable
{
  home.packages = [ pkgs.rnote ];
}
