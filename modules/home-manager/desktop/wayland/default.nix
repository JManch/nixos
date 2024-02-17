{ lib
, pkgs
, config
, osConfig
, ...
}:
let
  inherit (lib) mkIf utils fetchers;
  isWayland = fetchers.isWayland config;
  osDesktopEnabled = osConfig.usrEnv.desktop.enable;
in
{
  imports = utils.scanPaths ./.;

  config = mkIf (osDesktopEnabled && isWayland) {
    home.packages = [ pkgs.wl-clipboard ];
  };
}
