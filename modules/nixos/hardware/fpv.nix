{
  lib,
  pkgs,
  config,
}:
let
  inherit (lib) ns;
in
{
  asserts = [
    config.${ns}.hm.${ns}.programs.desktop.chromium.enable
    "The fpv module requires the chromium home-manager module to be enabled"
  ];

  ns.userPackages = [
    (
      assert lib.assertMsg (
        pkgs.edgetx.version == "2.11.3"
      ) "Remove edgetx override if 2.12 has released";
      pkgs.${ns}.edgetx-unstable
    )
    pkgs.${ns}.expresslrs-configurator
    (pkgs.makeDesktopItem {
      name = "betaflight";
      desktopName = "Betaflight";
      type = "Application";
      exec = "chromium --app=https://app.betaflight.com/";
      icon = pkgs.fetchurl {
        url = "https://raw.githubusercontent.com/betaflight/betaflight-configurator/0c72c9f4d9a346800e07f45d8bb813dddde0249d/assets/linux/icon/bf_icon_128.png";
        hash = "sha256-O5O/igPx4Ufh+iqW9Xed9pPUDzEc5K90i9BhBA115ts=";
      };
    })
  ];

  # We use wifi
  # services.udev.packages = [ pkgs.${ns}.expresslrs-configurator ];

  ns.persistenceHome.directories = [ ".config/EdgeTX" ];
}
