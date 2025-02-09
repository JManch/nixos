{ lib, pkgs }:
{
  home.packages = [
    (pkgs.supersonic-wayland.overrideAttrs {
      version = "git";

      src = pkgs.fetchFromGitHub {
        owner = "JManch";
        repo = "supersonic";
        rev = "4e619c08f89b0560639a137bcda0c944dc30198e";
        hash = "sha256-2gtFWBL25LQIACap7JYtFJc1ShuhUg6oSwW7dlEKYqQ=";
      };

      patches = [ ../../../../patches/supersonicLargeVolumeSlider.patch ];

      vendorHash = "sha256-Y1oWiQUwL6TGtHs9CfksEzjaAYb9rFEewyN3Pvv7i0Q=";
    })
    (lib.hiPrio (
      pkgs.runCommand "supersonic-wayland-desktop-rename" { } ''
        mkdir -p $out/share/applications
        substitute ${pkgs.supersonic-wayland}/share/applications/supersonic-wayland.desktop $out/share/applications/supersonic-wayland.desktop \
          --replace-fail "Name=Supersonic (Wayland)" "Name=Supersonic"
      ''
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
