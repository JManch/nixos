{
  lib,
  pkgs,
  config,
}:
let
  inherit (lib) ns optional;
  inherit (config.${ns}.desktop) style hyprland;

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
  ]
  ++ optional (config.home.username == "joshua") unzipMusicHomelab;

  ns.desktop.hyprland.settings = {
    workspace = [
      "special:music, gapsin:${toString (style.gapSize * 2)}, gapsout:${toString (style.gapSize * 4)}"
    ];

    bind = [
      "${hyprland.modKey}, S, togglespecialworkspace, music"
      "${hyprland.modKey}SHIFT, S, movetoworkspacesilent, special:music"
    ];

    windowrule = [ "float, class:^(spek)$" ];
  };
}
