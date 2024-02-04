{ lib
, pkgs
, config
, nixosConfig
, ...
}:
{
  imports = lib.utils.scanPaths ./.;

  config =
    let
      isWayland = lib.fetchers.isWayland config;
      osDesktopEnabled = nixosConfig.usrEnv.desktop.enable;
    in
    lib.mkIf (osDesktopEnabled && isWayland) {
      home.packages = with pkgs; [
        wl-clipboard
      ];
    };
}
