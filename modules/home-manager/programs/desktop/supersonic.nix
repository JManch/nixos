{ lib, pkgs }:
{
  home.packages = [
    (pkgs.supersonic.overrideAttrs (old: {
      version = "git";

      src = pkgs.fetchFromGitHub {
        owner = "dweymouth";
        repo = "supersonic";
        rev = "31df8ab054e010978558739d962fcb69f26fbf89";
        hash = "sha256-s4q7RvAG3oDBQ9ktfonEJXjrX/75MUpVq+9c43TRgWM=";
      };

      patches = [ ../../../../patches/supersonic-large-volume-slider.patch ];

      tags = old.tags ++ [ "migrated_fynedo" ];

      vendorHash = "sha256-E1F/89+pyIhmPSsfxWeMFTktGekU56HzSh3qIo8KAzo=";

      # desktopItems = lib.singleton (
      #   pkgs.makeDesktopItem {
      #     name = "supersonic";
      #     exec = "supersonic-wayland";
      #     icon = "supersonic";
      #     desktopName = "Supersonic";
      #     genericName = "Subsonic Client";
      #     comment = "A lightweight cross-platform desktop client for Subsonic music servers";
      #     type = "Application";
      #     categories = [
      #       "Audio"
      #       "AudioVideo"
      #     ];
      #   }
      # );

      # When it's named supersonic-wayland it breaks the icon in a bunch of places
      # postInstall =
      #   old.postInstall
      #   + ''
      #     find $out/share/icons/hicolor -type f -name "supersonic-wayland.png" -execdir mv {} supersonic.png \;
      #   '';
    }))
  ];

  ns.desktop = {
    services.playerctl.musicPlayers = lib.mkBefore [ "Supersonic" ];

    hyprland.settings.windowrule = [
      "workspace special:social silent, initialTitle:^(Supersonic)$"
    ];
  };

  ns.persistence.directories = [
    ".config/supersonic"
    ".cache/supersonic"
  ];
}
