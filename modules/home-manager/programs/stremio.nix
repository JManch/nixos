{ pkgs, ... }: {
  home.packages = [ pkgs.stremio ];

  impermanence.directories = [
    ".local/share/Smart Code ltd"
    ".stremio-server" # Cache is stored here
  ];
}
