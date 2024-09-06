{
  ns,
  lib,
  pkgs,
  isWayland,
  ...
}:
{
  imports = lib.${ns}.scanPaths ./.;

  config = lib.mkIf isWayland { home.packages = [ pkgs.wl-clipboard ]; };
}
