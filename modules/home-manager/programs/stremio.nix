{ pkgs, ... }: {
  home.packages = [ pkgs.stremio ];

  impermanence.directories = [
    ".local/share/Smart Code ltd"
  ];
}
