{ lib, pkgs }:
{
  home.packages = [
    (pkgs.supersonic-wayland.overrideAttrs (old: {
      version = "git";

      src = pkgs.fetchFromGitHub {
        owner = "JManch";
        repo = "supersonic";
        rev = "4e619c08f89b0560639a137bcda0c944dc30198e";
        hash = "sha256-2gtFWBL25LQIACap7JYtFJc1ShuhUg6oSwW7dlEKYqQ=";
      };

      patches = [ ../../../../patches/supersonicLargeVolumeSlider.patch ];

      vendorHash = "sha256-Y1oWiQUwL6TGtHs9CfksEzjaAYb9rFEewyN3Pvv7i0Q=";

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

  ns.desktop = {
    services.playerctl.musicPlayers = lib.mkBefore [ "Supersonic" ];

    hyprland.settings.windowrulev2 = [
      "workspace special:social silent, initialTitle:^(Supersonic)$"
    ];
  };

  ns.persistence.directories = [
    ".config/supersonic"
    ".cache/supersonic"
  ];
}
