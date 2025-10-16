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
    hyprland.settings = {
      windowrule = [
        "bordercolor 0xff1ED760, initialTitle:^(Spotify( Premium)?)$"
        "workspace special:music silent, title:^(Spotify( Premium)?)$"
      ];
    };

    services.playerctl.musicPlayers = [ "spotify" ];

    uwsm.appUnitOverrides."spotify-.scope" = ''
      [Scope]
      KillMode=mixed
    '';
  };

  ns.persistence.directories = [
    ".config/spotify"
    ".cache/spotify"
  ];
}
