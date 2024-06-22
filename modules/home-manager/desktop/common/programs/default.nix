{ lib, pkgs, osConfig, ... }:
{
  imports = lib.utils.scanPaths ./.;

  config = lib.mkIf osConfig.modules.system.desktop.enable {
    home.packages = [ pkgs.gnome.nautilus ];
  };
}
