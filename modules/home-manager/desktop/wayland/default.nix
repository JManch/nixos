{ lib, pkgs, osConfig, ... }:
let
  inherit (lib) mkIf utils fetchers;
  isWayland = fetchers.isWayland osConfig;
  osDesktopEnabled = osConfig.modules.system.desktop.enable;
in
{
  imports = utils.scanPaths ./.;

  config = mkIf (osDesktopEnabled && isWayland) {
    home.packages = [ pkgs.wl-clipboard ];
  };
}
