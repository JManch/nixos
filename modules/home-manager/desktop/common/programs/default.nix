{ lib, pkgs, desktopEnabled, ... }:
{
  imports = lib.utils.scanPaths ./.;

  config = lib.mkIf desktopEnabled {
    home.packages = [ pkgs.gnome.nautilus ];
  };
}
