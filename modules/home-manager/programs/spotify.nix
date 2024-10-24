{
  ns,
  lib,
  pkgs,
  config,
  osConfig',
  ...
}:
let
  inherit (lib)
    mkIf
    hiPrio
    getExe
    getExe'
    ;
  cfg = config.${ns}.programs.spotify;
  desktopCfg = config.${ns}.desktop;

  spotify-player =
    (lib.${ns}.addPatches pkgs.spotify-player [ ../../../patches/spotifyPlayerNotifs.patch ]).override
      { withDaemon = false; };

  spotifyPlayer = getExe spotify-player;

  modifySpotifyVolume =
    let
      jaq = getExe pkgs.jaq;
      awk = getExe pkgs.gawk;
      notifySend = getExe pkgs.libnotify;
      pwDump = getExe' pkgs.pipewire "pw-dump";
      bc = getExe pkgs.bc;
    in
    pkgs.writeShellScript "spotify-modify-volume" ''
      # WARN: Unfortunately getting the node ID of a specific application is
      # tricky https://gitlab.freedesktop.org/pipewire/wireplumber/-/issues/395
      spotify_id=$(${pwDump} | ${jaq} -r 'first(.[] | select((.type == "PipeWire:Interface:Node") and (.info?.props?["application.name"]? == "spotify"))) | .id')
      increment=$1

      if [ -z "$spotify_id" ]; then
        ${notifySend} --urgency=critical -t 2000 \
          -h 'string:x-canonical-private-synchronous:spotify-player-volume' 'Spotify' 'Application not running'
        exit 1
      fi

      round_volume() {
        multiple=''${increment#-}
        add_half=$(echo "scale=10; ($1 + $multiple/2)" | ${bc})
        rounded="$(echo "($add_half / $multiple) * $multiple" | ${bc})"
        echo "$(echo "scale=2; $rounded / 100" | ${bc})"
      }

      current_vol=$(wpctl get-volume "$spotify_id" | ${awk} '{print $2 * 100}')
      new_vol=$(round_volume $((current_vol + $increment)))

      wpctl set-volume -l 1.0 "$spotify_id" "$new_vol"
      actual_vol=$(wpctl get-volume "$spotify_id" | ${awk} '{print $2 * 100}')
      ${notifySend} --urgency=low -t 2000 \
        -h 'string:x-canonical-private-synchronous:spotify-player-volume' 'Spotify' "Volume ''${actual_vol%.*}%"
    '';
in
mkIf (cfg.enable && (osConfig'.${ns}.system.audio.enable or true)) {
  home.packages = [
    pkgs.spotify
    (hiPrio (
      pkgs.runCommand "spotify-desktop-rename" { } ''
        mkdir -p $out/share/applications
        substitute ${pkgs.spotify}/share/applications/spotify.desktop $out/share/applications/spotify.desktop \
          --replace-fail "Name=Spotify" "Name=Spotify Desktop"
      ''
    ))
    spotify-player
  ];

  services.playerctld.enable = true;

  xdg.configFile = {
    "spotify-player/app.toml".text = # toml
      ''
        theme = "default2"
        playback_format = """
        {track}
        {artists} • {album}
        {metadata}"""
        app_refresh_duration_in_ms = 32
        playback_refresh_duration_in_ms = 0
        page_size_in_rows = 20
        play_icon = ""
        pause_icon = ""
        liked_icon = ""
        border_type = "Rounded"
        progress_bar_type = "Line"
        playback_window_position = "Bottom"
        cover_img_length = 12
        cover_img_width = 6
        cover_img_scale = 1.0
        playback_window_width = 6
        enable_media_control = true
        enable_streaming = "Always"
        enable_notify = true
        enable_cover_image_cache = true
        default_device = "spotify-player"

        [copy_command]
        command = "${getExe' pkgs.wl-clipboard "wl-copy"}"

        [notify_format]
        summary = "{track}"
        body = "{artists} • {album}"

        [device]
        name = "spotify-player"
        device_type = "computer"
        volume = 60
        bitrate = 320
        audio_cache = true
        normalization = false
      '';

    "spotify-player/theme.toml".text = # toml
      ''
        [[themes]]
        name = "default2"
        [themes.component_style]
        block_title = { fg = "Green", modifiers = ["Bold"] }
        border = { fg = "BrightBlack" }
        playback_track = { fg = "White", modifiers = ["Bold"] }
        playback_artists = { fg = "White" }
        playback_album = { fg = "White", modifiers = ["Italic"] }
        playback_metadata = { fg = "BrightBlack" }
        playback_progress_bar = { bg = "BrightBlack", fg = "Green" }
        current_playing = { fg = "Green", modifiers = ["Bold"] }
        page_desc = { fg = "Blue", modifiers = ["Bold"] }
        table_header = { fg = "Blue" }
        selection = { modifiers = ["Bold", "Reversed"] }
      '';
  };

  xdg.desktopEntries.spotify-player = mkIf config.${ns}.desktop.enable {
    name = "Spotify";
    genericName = "Music Player";
    exec = "${desktopCfg.terminal.exePath} --title Spotify --option font.size=11 -e ${spotifyPlayer}";
    terminal = false;
    type = "Application";
    categories = [ "Audio" ];
    icon = "spotify";
  };

  desktop.hyprland.settings =
    let
      inherit (config.${ns}.desktop.hyprland) modKey;
      colors = config.colorScheme.palette;
      playerctl = lib.getExe pkgs.playerctl;
    in
    {
      windowrulev2 = [
        "bordercolor 0xff${colors.base0B}, initialTitle:^(Spotify( Premium)?)$"
        "workspace special:social silent, title:^(Spotify( Premium)?)$"
      ];

      bindr = [
        "${modKey}, ${modKey}_R, exec, ${playerctl} play-pause --player spotify_player,spotify"
        "${modKey}SHIFT, ${modKey}_R, exec, ${playerctl} play-pause --ignore-player spotify_player,spotify"
      ];

      bind = [
        "${modKey}, Period, exec, ${playerctl} next --player spotify_player,spotify"
        "${modKey}, Comma, exec, ${playerctl} previous --player spotify_player,spotify"
        ", XF86AudioNext, exec, ${playerctl} next"
        ", XF86AudioPrev, exec, ${playerctl} previous"
        ", XF86AudioPlay, exec, ${playerctl} play"
        ", XF86AudioPause, exec, ${playerctl} pause"
      ];

      binde = [
        "${modKey}, XF86AudioRaiseVolume, exec, ${modifySpotifyVolume} 5"
        "${modKey}, XF86AudioLowerVolume, exec, ${modifySpotifyVolume} -5"
      ];
    };

  persistence.directories = [
    ".config/spotify"
    ".cache/spotify"
    ".cache/spotify-player"
  ];
}
