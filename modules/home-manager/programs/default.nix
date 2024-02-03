{ lib, ... }:
let
  inherit (lib) mkEnableOption mkOption types;
in
{
  imports = lib.utils.scanPaths ./.;

  options.modules.programs = {
    alacritty = {
      enable = mkEnableOption "Alacritty";
      opacity = mkOption {
        type = types.float;
        default = 0.7;
      };
    };

    btop.enable = mkEnableOption "btop";
    cava.enable = mkEnableOption "cava";
    firefox.enable = mkEnableOption "Firefox";
    git.enable = mkEnableOption "git and lazygit";
    neovim.enable = mkEnableOption "Neovim";
    spotify.enable = mkEnableOption "Spotify";
    fastfetch.enable = mkEnableOption "Fastfetch";
    discord.enable = mkEnableOption "Discord";
    obs.enable = mkEnableOption "Obs";
    vscode.enable = mkEnableOption "vscode";
    stremio.enable = mkEnableOption "stremio";
    mpv.enable = mkEnableOption "mpv";
    chatterino.enable = mkEnableOption "chatterino";
    images.enable = mkEnableOption "images";
    anki.enable = mkEnableOption "anki";
    zathura.enable = mkEnableOption "zathura";
    qbittorrent.enable = mkEnableOption "qbittorrent";
    mangohud.enable = mkEnableOption "mangohud";
    r2modman.enable = mkEnableOption "r2modman";
    lutris.enable = mkEnableOption "lutris";
  };
}
