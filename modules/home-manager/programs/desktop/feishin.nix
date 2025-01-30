{ lib, pkgs }:
let
  # https://github.com/NixOS/nixpkgs/pull/377468
  inherit
    (import (fetchTarball {
      url = "https://github.com/DoctorDalek1963/nixpkgs/archive/ca840a01ced92c13606cb28a68bdc2f367452f9f.tar.gz";
      sha256 = "sha256:0bzs81v1n1nrfsk41dvypcajsrgcrlzwp06s07dfmd8wbzq6r08q";
    }) { inherit (pkgs) system; })
    feishin
    ;
in
{
  home.packages = [
    # we don't want feishin loading mpv scripts
    (pkgs.symlinkJoin {
      name = "feishin-mpv-unwrapped";
      paths = [ feishin ];
      nativeBuildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        wrapProgram $out/bin/feishin \
          --prefix PATH : ${pkgs.mpv-unwrapped}/bin
      '';
    })
  ];

  desktop.hyprland.settings.windowrulev2 = [
    "workspace special:social silent, class:^(feishin)$"
  ];

  nsConfig = {
    desktop.services.playerctl.musicPlayers = lib.mkBefore [ "Feishin" ];
    persistence.directories = [ ".config/feishin" ];
  };
}
