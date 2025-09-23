{
  lib,
  pkgs,
  sources,
}:
{
  home.packages = [
    (pkgs.supersonic.overrideAttrs (old: {
      version = "0-unstable-${sources.supersonic.revision}";
      src = sources.supersonic;
      patches = [ ../../../../patches/supersonic-large-volume-slider.patch ];
      tags = old.tags ++ [ "migrated_fynedo" ];
      vendorHash = "sha256-Sh3PxRwb6ElSeWzdvIQ+nD9VVGlpUDwxG7nAoGWPTRQ=";

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

  ns.programs.desktop.music.enable = true;

  ns.desktop = {
    services.playerctl.musicPlayers = lib.mkBefore [ "Supersonic" ];

    hyprland.settings.windowrule = [
      "workspace special:music silent, initialTitle:^(Supersonic)$"
    ];
  };

  ns.persistence.directories = [
    ".config/supersonic"
    ".cache/supersonic"
  ];
}
