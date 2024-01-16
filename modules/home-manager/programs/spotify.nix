{ lib
, pkgs
, config
, inputs
, hostname
, nixosConfig
, ...
}:
let
  spicePkgs = inputs.spicetify-nix.packages.${pkgs.system}.default;
  cfg = config.modules.programs.spotify;
  desktopCfg = config.modules.desktop;
  colors = config.colorscheme.colors;
in
{
  imports = [
    inputs.spicetify-nix.homeManagerModule
  ];

  config = lib.mkIf cfg.enable {

    assertions = [
      {
        assertion = cfg.enable -> nixosConfig.modules.system.audio.enable;
        message = "Why enable spotify with no system audio?";
      }
    ];

    home.packages = with pkgs; [
      spotify
      spotify-tui
      playerctl
    ];

    age.secrets.spotify.file = ../../../secrets/spotify.age;

    services = {
      spotifyd = {
        enable = true;
        package = pkgs.spotifyd.override { withMpris = true; };
        settings.global =
          let
            creds = config.age.secrets.spotify.path;
          in
          {
            username_cmd = "${pkgs.coreutils}/bin/head -1 $(echo ${creds})";
            password_cmd = "${pkgs.coreutils}/bin/tail -1 $(echo ${creds})";
            autoplay = true;
            use_mpris = true;
            backend = "alsa";
            device_name = hostname;
            device_type = "computer";
            bitrate = 320;
            cache_path = "${config.xdg.cacheHome}/spotifyd";
            volume_normalisation = false;
          };
      };
    };

    # TODO: Switch to spotify_player https://github.com/aome510/spotify-player
    xdg.configFile."spotify-tui/config.yml".text = /* yaml */ ''
      theme:
        active: Blue
        banner: Green
        error_border: Red
        error_text: Red
        hint: Yellow
        hovered: LightGreen
        inactive: Gray
        playbar_progress: Green
        playbar_progress_text: Black
        playbar_text: White
        selected: Green
        text: White
        header: White
      behavior:
        enable_text_emphasis: false
        volume_increment: 5
        liked_icon: 
        shuffle_icon: 󰒟
        repeat_track_icon: 󰑘
        repeat_context_icon: 󰑖
        playing_icon: 
        paused_icon: 
        set_window_title: true
    '';

    # Spicetify is broken for now
    programs.spicetify = {
      enable = false;
      theme = {
        name = "text";
        src = pkgs.fetchgit {
          url = "https://github.com/JManch/spicetify-themes";
          sha256 = "sha256-WvQNRUD9mfH9/yPX6WzpJGTXPNLpYjz3iMhZqYlmFOM=";
        };
        injectCss = true;
        replaceColors = true;
        overwriteAssets = true;
        siebarConfig = true;
      };
      colorScheme = "custom";
      customColorScheme = {
        text = "FFFFFF";
        accent = "${colors.base0B}";
        accent-active = "${colors.base0B}";
        accent-inactive = "${colors.base01}";
        banner = "${colors.base0B}";
        border-active = "${colors.base04}";
        border-inactive = "${colors.base04}";
        header = "${colors.base04}";
        highlight = "${colors.base02}";
        main = "${colors.base00}";
        notification = "${colors.base02}";
        notification-error = "${colors.base08}";
        subtext = "${colors.base05}";
      };

      enabledExtensions = with spicePkgs.extensions; [
        fullAppDisplay
        keyboardShortcut
        fullAlbumDate
        songStats
        history
        genre
        hidePodcasts
        shuffle
      ];

      enabledCustomApps = with spicePkgs.apps; [
        marketplace
        new-releases
        lyrics-plus
        {
          name = "localFiles";
          src = "${config.home.homeDirectory}/music";
          appendName = false;
        }
      ];
    };

    impermanence = {
      directories = [
        ".cache/spotify"
        ".cache/spotifyd"
        ".config/spotify"
      ];
      files = [
        ".config/spotify-tui/.spotify_token_cache.json"
        ".config/spotify-tui/client.yml"
      ];
    };

    desktop.hyprland.settings =
      let
        modKey = config.modules.desktop.hyprland.modKey;
        playerctl = "${pkgs.playerctl}/bin/playerctl --player=spotifyd,spotify,%any";
      in
      {
        windowrulev2 =
          lib.mkIf (desktopCfg.windowManager == "hyprland")
            [ "bordercolor 0xff${colors.base0B}, initialTitle:^(Spotify( Premium)?)$" ];
        bindr = [
          "${modKey}, ${modKey}_R, exec, ${playerctl} play-pause"
        ];
        bind = [
          "${modKey}, Comma, exec, ${playerctl} previous"
          "${modKey}, Period, exec, ${playerctl} next"
          # "${modKey}, XF86AudioRaiseVolume, exec, ${pkgs.libsForQt5.qt5.qttools.bin}/bin/qdbus --literal org.mpris.MediaPlayer2.spotifyd /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2.Player.VolumeUp"
          # "${modKey}, XF86AudioLowerVolume, exec, ${pkgs.libsForQt5.qt5.qttools.bin}/bin/qdbus --literal org.mpris.MediaPlayer2.spotifyd /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2.Player.VolumeDown"
        ];
      };
  };
}
