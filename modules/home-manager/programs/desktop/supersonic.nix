{ lib, pkgs }:
{
  home.packages = [
    (pkgs.supersonic-wayland.overrideAttrs {
      version = "git";

      src = pkgs.fetchFromGitHub {
        owner = "JManch";
        repo = "supersonic";
        rev = "7458a890711c765fcf1f09aac65806c4afda9cce";
        hash = "sha256-x4pD5N29XjrltF4c89lk3KMTC0Zf+PCjpGJJ4lK5Ndk=";
      };

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
