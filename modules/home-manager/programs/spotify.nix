{ lib
, pkgs
, config
, osConfig
, ...
}:
let
  inherit (lib) mkIf utils getExe getExe';
  cfg = config.modules.programs.spotify;
  desktopCfg = config.modules.desktop;

  spotify-player = (
    utils.addPatches
      pkgs.spotify-player
      [ ../../../patches/spotifyPlayerNotifs.patch ]
  ).override {
    withDaemon = false;
  };

  spotifyPlayer = getExe spotify-player;

  modifySpotifyVolume =
    let
      jaq = getExe pkgs.jaq;
      notifySend = getExe pkgs.libnotify;
      sleep = getExe' pkgs.coreutils "sleep";
    in
    pkgs.writeShellScript "spotify-modify-volume" ''
      ${spotifyPlayer} playback volume --offset -- $1
      ${sleep} 0.2 # volume takes some time to update
      new_volume=$(${spotifyPlayer} get key playback | ${jaq} -r '.device.volume_percent')
      ${notifySend} --urgency=low -t 2000 \
        -h 'string:x-canonical-private-synchronous:spotify-player-volume' 'Spotify' "Volume ''${new_volume}%"
    '';
in
mkIf (cfg.enable && osConfig.modules.system.audio.enable)
{
  home.packages = with pkgs; [
    # Need this for the spotify-player desktop icon
    (spotify.overrideAttrs (oldAttrs: {
      postInstall = /*bash*/ ''
        rm "$out/share/applications/spotify.desktop"
      '';
    }))
    spotify-player
  ];

  services.playerctld.enable = true;

  xdg.configFile = {
    "spotify-player/app.toml".text = /* toml */ ''

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

    "spotify-player/theme.toml".text = /* toml */ ''

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

  xdg.desktopEntries."spotify-player" = mkIf osConfig.usrEnv.desktop.enable {
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
      inherit (config.modules.desktop.hyprland) modKey;
      colors = config.colorScheme.palette;
      playerctl = lib.getExe pkgs.playerctl;
    in
    {
      windowrulev2 = [
        "bordercolor 0xff${colors.base0B}, initialTitle:^(Spotify( Premium)?)$"
        "workspace special:social silent, title:^(Spotify( Premium)?)$"
      ];

      bindr = [
        "${modKey}, ${modKey}_R, exec, ${playerctl} play-pause --player spotify_player"
        "${modKey}SHIFT, ${modKey}_R, exec, ${playerctl} play-pause --ignore-player spotify_player"
      ];

      bind = [
        "${modKey}, Period, exec, ${playerctl} next --player spotify_player"
        "${modKey}, Comma, exec, ${playerctl} previous --player spotify_player"
        ", XF86AudioNext, exec, ${playerctl} next"
        ", XF86AudioPrev, exec, ${playerctl} previous"
        ", XF86AudioPlay, exec, ${playerctl} play"
        ", XF86AudioPause, exec, ${playerctl} pause"
        "${modKey}, XF86AudioRaiseVolume, exec, ${modifySpotifyVolume.outPath} 5"
        "${modKey}, XF86AudioLowerVolume, exec, ${modifySpotifyVolume.outPath} -5"
      ];
    };

  persistence.directories = [
    ".config/spotify"
    ".cache/spotify"
    ".cache/spotify-player"
  ];
}
