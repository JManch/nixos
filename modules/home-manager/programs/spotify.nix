{ inputs
, config
, pkgs
, lib
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
    programs.spicetify = {
      enable = true;
      theme = {
        name = "text";
        src = pkgs.fetchgit {
          url = "https://github.com/JManch/spicetify-themes";
          sha256 = "sha256-WvQNRUD9mfH9/yPX6WzpJGTXPNLpYjz3iMhZqYlmFOM=";
        };
        injectCss = true;
        replaceColors = true;
        overwriteAssets = true;
        sidebarConfig = true;
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

    impermanence.directories = [
      ".cache/spotify"
      ".config/spotify"
    ];

    desktop.hyprland.settings.windowrulev2 =
      lib.mkIf (desktopCfg.windowManager == "hyprland")
        [ "bordercolor 0xff${colors.base0B}, initialTitle:^(Spotify( Premium)?)$" ];
  };
}
