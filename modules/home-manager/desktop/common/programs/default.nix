{ lib, pkgs, osConfig, ... }:
{
  imports = lib.utils.scanPaths ./.;

  config = lib.mkIf osConfig.usrEnv.desktop.enable {
    home.packages = [ pkgs.gnome.nautilus ];
  };
}
