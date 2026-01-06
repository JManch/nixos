{
  lib,
  pkgs,
  config,
}:
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

    # For some reason spotify ignores SIGTERM sent to the main PID. On Hyprland
    # we can send a dispatcher to cleanly close the window (and process). Have
    # to used KillMode=mixed to avoid a coredump from attempting to close all
    # processes at once.
    uwsm.appUnitOverrides."spotify@.service" = lib.mkIf (lib.${lib.ns}.isHyprland config) ''
      [Service]
      ExecStop=-${pkgs.writeShellScript "hypr-close-spotify" ''
        ${lib.getExe' pkgs.hyprland "hyprctl"} dispatch closewindow pid:$MAINPID &>/dev/null
      ''}
      KillMode=mixed
    '';
  };

  ns.persistence.directories = [
    ".config/spotify"
    ".cache/spotify"
  ];
}
