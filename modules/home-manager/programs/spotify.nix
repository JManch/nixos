{ lib
, pkgs
, config
, nixosConfig
, ...
}:
let
  cfg = config.modules.programs.spotify;
in
{
  config = lib.mkIf (cfg.enable && nixosConfig.modules.system.audio.enable) {

    home.packages = with pkgs; [
      spotify # need this for the spotify-player desktop icon
      spotify-player
    ];

    # TODO: Make the colors nicer
    xdg.configFile."spotify-player/app.toml".text = /* toml */ ''
      theme = "default"
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
      volume = 80
      bitrate = 320
      audio_cache = true
      normalization = false
    '';

    xdg.desktopEntries."spotify-player" = {
      name = "Spotify";
      genericName = "Music Player";
      exec = "${pkgs.alacritty}/bin/alacritty --title Spotify --option font.size=11 -e ${pkgs.spotify-player}/bin/spotify_player";
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
        modKey = config.modules.desktop.hyprland.modKey;
        spotifyPlayer = "${pkgs.spotify-player}/bin/spotify_player playback";
      in
      {
        # windowrulev2 =
        #   lib.mkIf (desktopCfg.windowManager == "hyprland")
        #     [ "bordercolor 0xff${colors.base0B}, initialTitle:^(Spotify( Premium)?)$" ];
        bindr = [
          "${modKey}, ${modKey}_R, exec, ${spotifyPlayer} play-pause"
        ];
        bind = [
          "${modKey}, Comma, exec, ${spotifyPlayer} previous"
          "${modKey}, Period, exec, ${spotifyPlayer} next"
          # TODO: Display current volume in notification by parsing "spotify_player get key playback"
          "${modKey}, XF86AudioRaiseVolume, exec, ${spotifyPlayer} volume --offset 5"
          "${modKey}, XF86AudioLowerVolume, exec, ${spotifyPlayer} volume --offset -- -5"
        ];
      };
  };
}
