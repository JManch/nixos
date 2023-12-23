{
  inputs,
  pkgs,
  ...
}: let
  spicePkgs = inputs.spicetify-nix.packages.${pkgs.system}.default;
in {
  imports = [
    inputs.spicetify-nix.homeManagerModule
  ];

  programs.spicetify = {
    enable = true;
    theme = spicePkgs.themes.DefaultDynamic;
    enabledExtensions = with spicePkgs.extensions; [
      fullAppDisplay
      keyboardShortcut
      fullAlbumDate
      skipStats
      songStats
      history
      genre
      hidePodcasts
      shuffle
    ];
  };
}
