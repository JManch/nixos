{ lib
, pkgs
, config
, osConfig
, ...
}:
{
  imports = lib.utils.scanPaths ./.;

  config =
    let
      isWayland = lib.fetchers.isWayland config;
      osDesktopEnabled = osConfig.usrEnv.desktop.enable;
    in
    lib.mkIf (osDesktopEnabled && isWayland) {
      home.packages = with pkgs; [
        wl-clipboard
      ];
    };
}
