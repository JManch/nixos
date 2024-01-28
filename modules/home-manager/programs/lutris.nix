{ lib, pkgs, config, ... }:
let
  cfg = config.modules.programs.lutris;
  lutris = pkgs.lutris.override {
    extraPkgs = pkgs: with pkgs; [
      wineWowPackages.stable
      wineWowPackages.staging
    ];
  };
in
lib.mkIf cfg.enable
{
  home.packages = [
    lutris
  ];

  # Install lutris games to ~/files/games

  impermanence.directories = [
    ".local/share/lutris"
    ".config/lutris"
    ".cache/lutris"
  ];
}
