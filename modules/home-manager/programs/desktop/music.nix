{ lib, pkgs }:
let
  inherit (lib) ns;

  unzipMusicHomelab = pkgs.writeShellApplication {
    name = "unzip-music-homelab";
    runtimeInputs = [
      pkgs.sshfs
      pkgs.gnugrep
      pkgs.util-linux
      pkgs.unzip
      pkgs.${ns}.resample-flacs
    ];
    text = ''
      mkdir -p ~/homelab-{slskd-downloads,music}
      if ! mount -l | grep -q homelab-slskd-downloads; then
        sshfs joshua@homelab.lan:/persist/media/slskd/downloads /home/joshua/homelab-slskd-downloads
      fi

      if ! mount -l | grep -q homelab-music; then
        sshfs joshua@homelab.lan:/persist/media/music /home/joshua/homelab-music
      fi

      tmp=$(mktemp -d)
      unzip "$1" -d "$tmp"
      resample-flacs "$tmp"
      mv "$tmp" "$HOME/homelab-slskd-downloads/''${1%.*}"
    '';
  };
in
{
  home.packages = [
    pkgs.picard
    pkgs.spek
    pkgs.${ns}.resample-flacs
    unzipMusicHomelab
  ];

  ns.programs.shell.qobuz-dl.enable = true;

  ns.desktop.hyprland.settings.windowrule = [ "match:class spek, float true" ];
}
