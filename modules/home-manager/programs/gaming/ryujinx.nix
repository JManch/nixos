{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.${lib.ns}.programs.gaming.ryujinx;
in
lib.mkIf cfg.enable {
  home.packages = [ pkgs.ryujinx ];

  persistence.directories = [ ".config/Ryujinx" ];
}
