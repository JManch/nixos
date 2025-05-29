{
  lib,
  pkgs,
  config,
  selfPkgs,
}:
let
  inherit (lib) ns mkIf;
  inherit (lib.${ns}) sshAddQuiet;
  inherit (config.${ns}.desktop) style hyprland;
in
{
  home.packages = [
    pkgs.picard
    pkgs.spek
    selfPkgs.resample-flacs
  ];

  programs.zsh.initContent =
    mkIf (config.home.username == "joshua") # bash
      ''
        unzip-music-homelab() {
          mkdir -p ~/homelab-{slskd-downloads,music}
          if ! mount -l | grep -q homelab-slskd-downloads; then
            ${sshAddQuiet pkgs}
            sshfs joshua@homelab.lan:/persist/media/slskd/downloads /home/joshua/homelab-slskd-downloads
          fi

          if ! mount -l | grep -q homelab-music; then
            ${sshAddQuiet pkgs}
            sshfs joshua@homelab.lan:/persist/media/music /home/joshua/homelab-music
          fi

          tmp=$(mktemp -d)
          unzip "$1" -d "$tmp"
          resample-flacs "$tmp"
          mv "$tmp" ~/homelab-slskd-downloads/''${1%.*}
        }
      '';

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
