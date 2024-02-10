{ lib, ... }:
let
  inherit (lib) mkEnableOption mkOption types;
in
{
  imports = lib.utils.scanPaths ./.;

  options.modules.programs = {
    alacritty.enable = mkEnableOption "alacritty";
    btop.enable = mkEnableOption "btop";
    cava.enable = mkEnableOption "cava";
    firefox.enable = mkEnableOption "firefox";
    torBrowser.enable = mkEnableOption "tor browser";
    git.enable = mkEnableOption "git and lazygit";
    neovim.enable = mkEnableOption "neovim";
    spotify.enable = mkEnableOption "spotify";
    fastfetch.enable = mkEnableOption "fastfetch";
    discord.enable = mkEnableOption "discord";
    obs.enable = mkEnableOption "obs";
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
