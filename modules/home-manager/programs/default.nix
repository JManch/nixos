{ lib, ... }:
let
  inherit (lib) mkEnableOption;
in
{
  imports = lib.utils.scanPaths ./.;

  options.modules.programs = {
    alacritty.enable = mkEnableOption "Alacritty";
    btop.enable = mkEnableOption "btop";
    cava.enable = mkEnableOption "cava";
    firefox.enable = mkEnableOption "Firefox";
    torBrowser.enable = mkEnableOption "Tor Browser";
    git.enable = mkEnableOption "Git and Lazygit";
    neovim.enable = mkEnableOption "Neovim";
    spotify.enable = mkEnableOption "Spotify";
    fastfetch.enable = mkEnableOption "Fastfetch";
    discord.enable = mkEnableOption "Discord";
    obs.enable = mkEnableOption "OBS";
    vscode.enable = mkEnableOption "VSCode";
    stremio.enable = mkEnableOption "Stremio";
    mpv.enable = mkEnableOption "mpv";
    chatterino.enable = mkEnableOption "Chatterino";
    images.enable = mkEnableOption "image tools";
    anki.enable = mkEnableOption "Anki";
    zathura.enable = mkEnableOption "Zathura";
    qbittorrent.enable = mkEnableOption "qBitorrent";
    mangohud.enable = mkEnableOption "MangoHud";
    r2modman.enable = mkEnableOption "r2modman";
    lutris.enable = mkEnableOption "Lutris";
    filenDesktop.enable = mkEnableOption "Filen Desktop";
    multiviewerF1.enable = mkEnableOption "Multiviewer for F1";
    prism-launcher.enable = mkEnableOption "Prism Launcher";
    unity.enable = mkEnableOption "Unity Game Engine";
    foot.enable = mkEnableOption "Foot";
  };
}
