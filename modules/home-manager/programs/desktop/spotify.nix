{
  lib,
  pkgs,
  config,
}:
let
  inherit (lib)
    ns
    mkIf
    hiPrio
    getExe
    getExe'
    ;

  spotify-player =
    (lib.${ns}.addPatches pkgs.spotify-player [ "spotify-player-notifs.patch" ]).override
      { withDaemon = false; };
in
{
  conditions = [ "osConfig.system.audio" ];

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

  xdg.desktopEntries.spotify-player =
    let
      xdg-terminal = getExe pkgs.xdg-terminal-exec;
      alacritty = getExe config.programs.alacritty.package;
      zsh = getExe pkgs.zsh;
    in
    mkIf config.${ns}.desktop.enable {
      name = "Spotify";
      genericName = "Music Player";
      exec = ''${xdg-terminal} --title=Spotify -e ${zsh} "-c" "${alacritty} msg config font.size=11 || true; ${spotify-player}"'';
      terminal = false;
      type = "Application";
      categories = [ "Audio" ];
      icon = "spotify";
    };

  ns.desktop = {
    hyprland.settings =
      let
        colors = config.colorScheme.palette;
      in
      {
        windowrule = [
          "bordercolor 0xff${colors.base0B}, initialTitle:^(Spotify( Premium)?)$"
          "workspace special:social silent, title:^(Spotify( Premium)?)$"
        ];
      };

    services.playerctl.musicPlayers = [
      "spotify_player"
      "spotify"
    ];

    uwsm.appUnitOverrides."spotify-.scope" = ''
      [Scope]
      KillMode=mixed
    '';
  };

  ns.persistence.directories = [
    ".config/spotify"
    ".cache/spotify"
    ".cache/spotify-player"
  ];
}
