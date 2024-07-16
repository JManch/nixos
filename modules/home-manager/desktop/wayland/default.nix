{
  lib,
  pkgs,
  isWayland,
  ...
}:
let
  inherit (lib) mkIf utils;
in
{
  imports = utils.scanPaths ./.;

  config = mkIf isWayland { home.packages = [ pkgs.wl-clipboard ]; };
}
