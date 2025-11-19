{ lib, pkgs }:
{
  conditions = [ "osConfig.system.audio" ];

  home.packages = [
    pkgs.spotify
    (lib.hiPrio (
      pkgs.runCommand "spotify-desktop-rename" { } ''
        mkdir -p $out/share/applications
        substitute ${pkgs.spotify}/share/applications/spotify.desktop $out/share/applications/spotify.desktop \
          --replace-fail "Name=Spotify" "Name=Spotify Desktop"
      ''
    ))
  ];

  ns.programs.desktop.music.enable = true;

  ns.desktop = {
    hyprland.windowRules."spotify" = {
      matchers.initial_title = "Spotify( Premium)?";
      params.border_color = "0xff1ED760";
      params.workspace = "special:music silent";
    };

    services.playerctl.musicPlayers = [ "spotify" ];

    uwsm.appUnitOverrides."spotify@.service" = ''
      [Service]
      KillMode=mixed
    '';
  };

  ns.persistence.directories = [
    ".config/spotify"
    ".cache/spotify"
  ];
}
