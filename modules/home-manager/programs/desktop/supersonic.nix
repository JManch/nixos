{ lib, pkgs }:
{
  home.packages = [
    (pkgs.supersonic-wayland.overrideAttrs (old: {
      version = "git";

      src = pkgs.fetchFromGitHub {
        owner = "JManch";
        repo = "supersonic";
        rev = "3a3774f5b64844984b7140ea28c298e961533cfa";
        hash = "sha256-ftvraAsYyUULp9Nh5vGtvy6ilAN1K6tAIAd5hRu0Xq0=";
      };

      patches = [ ../../../../patches/supersonicLargeVolumeSlider.patch ];

      vendorHash = "sha256-VEu8pNWpGAFQdf12r0vUE8EQJ2EF+T/tHzgYwVRW4Z0=";

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
        old.postInstall
        + ''
          find $out/share/icons/hicolor -type f -name "supersonic-wayland.png" -execdir mv {} supersonic.png \;
        '';
    }))
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
