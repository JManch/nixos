{ lib, ... }:
let
  inherit (lib) mkEnableOption mkOption types;
in
{
  imports = [
    ./alacritty.nix
    ./btop.nix
    ./cava.nix
    ./firefox
    ./git.nix
    ./neovim.nix
    ./spotify.nix
    ./fastfetch.nix
    ./discord.nix
    ./obs.nix
    ./vscode.nix
    ./stremio.nix
    ./steam.nix
    ./mangohud.nix
    ./mpv.nix
    ./chatterino.nix
    ./images.nix
    ./anki.nix
    ./zathura.nix
  ];

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
  };
}
