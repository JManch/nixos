{ lib
, pkgs
, config
, nixosConfig
, ...
}:
let
  cfg = config.modules.programs.spotify;
  spotifyPlayer = "${pkgs.spotify-player}/bin/spotify_player";
  modifySpotifyVolume = pkgs.writeShellScript "spotify-modify-volume" ''
    ${spotifyPlayer} playback volume --offset -- $1
    ${pkgs.coreutils}/bin/sleep 0.2 # volume takes some time to update
    new_volume=$(${spotifyPlayer} get key playback | ${pkgs.jaq}/bin/jaq -r '.device.volume_percent')
    ${pkgs.libnotify}/bin/notify-send --urgency=low -t 2000 -h 'string:x-canonical-private-synchronous:spotify-player-volume' 'Spotify' "Volume ''${new_volume}%"
  '';
in
{
  config = lib.mkIf (cfg.enable && nixosConfig.modules.system.audio.enable) {

    home.packages = with pkgs; [
      spotify # need this for the spotify-player desktop icon
      (spotify-player.override {
        withDaemon = false;
      })
    ];

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
        command = "${pkgs.wl-clipboard}/bin/wl-copy"

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
        [themes.palette]
        black = "black"
        red = "red"
        green = "green"
        yellow = "yellow"
        blue = "blue"
        magenta = "magenta"
        cyan = "cyan"
        white = "white"
        bright_black = "bright_black"
        bright_red = "bright_red"
        bright_green = "bright_green"
        bright_yellow = "bright_yellow"
        bright_blue = "bright_blue"
        bright_magenta = "bright_magenta"
        bright_cyan = "bright_cyan"
        bright_white = "bright_white"
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

    xdg.desktopEntries."spotify-player" = {
      name = "Spotify";
      genericName = "Music Player";
      exec = "${config.programs.alacritty.package}/bin/alacritty --title Spotify --option font.size=11 -e ${pkgs.spotify-player}/bin/spotify_player";
      terminal = false;
      type = "Application";
      categories = [ "Audio" ];
      icon = "spotify";
    };

    impermanence = {
      directories = [
        ".config/spotify"
        ".cache/spotify"
        ".cache/spotify-player"
      ];
    };

    desktop.hyprland.settings =
      let
        colors = config.colorscheme.palette;
        desktopCfg = config.modules.desktop;
        modKey = config.modules.desktop.hyprland.modKey;
      in
      {
        windowrulev2 =
          lib.mkIf (desktopCfg.windowManager == "hyprland")
            [ "bordercolor 0xff${colors.base0B}, initialTitle:^(Spotify( Premium)?)$" ];
        bindr = [
          "${modKey}, ${modKey}_R, exec, ${spotifyPlayer} playback play-pause"
        ];
        bind = [
          "${modKey}, Comma, exec, ${spotifyPlayer} playback previous"
          "${modKey}, Period, exec, ${spotifyPlayer} playback next"
          "${modKey}, XF86AudioRaiseVolume, exec, ${modifySpotifyVolume.outPath} 5"
          "${modKey}, XF86AudioLowerVolume, exec, ${modifySpotifyVolume.outPath} -5"
        ];
      };
  };
}
