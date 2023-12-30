{ inputs
, config
, pkgs
, lib
, ...
}:
let
  spicePkgs = inputs.spicetify-nix.packages.${pkgs.system}.default;
  cfg = config.modules.programs.spotify;
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
          sha256 = "sha256-0mWevxdbNCQibLir4KdgFZ9RX74NTm9qwWFd00J6pDw=";
        };
        injectCss = true;
        replaceColors = true;
        overwriteAssets = true;
        sidebarConfig = true;
      };
      colorScheme = "custom";
      customColorScheme = {
        text = "FFFFFF";
        accent = "${config.colorscheme.colors.base0B}";
        accent-active = "${config.colorscheme.colors.base0B}";
        accent-inactive = "${config.colorscheme.colors.base01}";
        banner = "${config.colorscheme.colors.base0B}";
        border-active = "${config.colorscheme.colors.base04}";
        border-inactive = "${config.colorscheme.colors.base04}";
        header = "${config.colorscheme.colors.base04}";
        highlight = "${config.colorscheme.colors.base02}";
        main = "${config.colorscheme.colors.base00}";
        notification = "${config.colorscheme.colors.base02}";
        notification-error = "${config.colorscheme.colors.base08}";
        subtext = "${config.colorscheme.colors.base05}";
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
  };
}
