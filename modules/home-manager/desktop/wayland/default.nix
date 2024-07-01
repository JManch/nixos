{ lib
, pkgs
, isWayland
, desktopEnabled
, ...
}:
let
  inherit (lib) mkIf utils;
in
{
  imports = utils.scanPaths ./.;

  config = mkIf (desktopEnabled && isWayland) {
    home.packages = [ pkgs.wl-clipboard ];
  };
}
