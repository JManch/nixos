{ lib, pkgs }:
{
  home.packages = [
    (pkgs.supersonic-wayland.overrideAttrs (
      final: prev: {
        version = "0.14.0";

        src = pkgs.fetchFromGitHub {
          owner = "dweymouth";
          repo = "supersonic";
          tag = "v${final.version}";
          hash = "sha256-ua2INyKPncXDOwzmKrgnRCb7q8CFEApEaYuBbQeau98=";
        };

        patches = [ ../../../../patches/supersonicLargeVolumeSlider.patch ];

        vendorHash = "sha256-5LxYD9kLUvKgXmDCw1SNBM6ay8Vayj+PyoZRVptSM0c=";

        desktopItems = lib.singleton (
          pkgs.makeDesktopItem {
            name = "supersonic";
            exec = "supersonic-wayland";
            icon = "supersonic";
            desktopName = "Supersonic";
            genericName = "Subsonic Client";
            comment = "A lightweight cross-platform desktop client for Subsonic music servers";
            type = "Application";
            categories = [
              "Audio"
              "AudioVideo"
            ];
          }
        );

        # When it's named supersonic-wayland it breaks the icon in a bunch of places
        postInstall =
          prev.postInstall
          + ''
            find $out/share/icons/hicolor -type f -name "supersonic-wayland.png" -execdir mv {} supersonic.png \;
          '';
      }
    ))
  ];

  desktop.hyprland.settings.windowrulev2 = [
    "workspace special:social silent, initialTitle:^(Supersonic)$"
  ];

  nsConfig = {
    desktop.services.playerctl.musicPlayers = lib.mkBefore [ "Supersonic" ];
    persistence.directories = [
      ".config/supersonic"
      ".cache/supersonic"
    ];
  };
}
