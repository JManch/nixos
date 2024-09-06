{
  ns,
  lib,
  pkgs,
  desktopEnabled,
  ...
}:
{
  imports = lib.${ns}.scanPaths ./.;

  config = lib.mkIf desktopEnabled { home.packages = [ pkgs.nautilus ]; };
}
