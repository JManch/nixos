{ lib, pkgs, config, ... }:
let
  cfg = config.modules.programs.gaming.lutris;

  lutris = pkgs.lutris.override {
    extraPkgs = pkgs: with pkgs; [
      wineWowPackages.stable
      wineWowPackages.staging
    ];
  };
in
lib.mkIf cfg.enable
{
  home.packages = [ lutris ];

  modules.programs.gaming.gameClasses = [ "bfv.exe" ];

  # Install lutris games to ~/files/games
  persistence.directories = [
    ".local/share/lutris"
    ".config/lutris"
    ".cache/lutris"
  ];
}
