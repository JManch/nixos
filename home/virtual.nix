{ inputs, pkgs, lib, ... }:
{
  imports = [
    ./home.nix
    ./shell
    ./programs/alacritty.nix
    ./programs/neovim
    ./programs/btop.nix
    ./programs/git.nix
    ./programs/firefox.nix
  ];

  programs.alacritty.settings.window.decorations = lib.mkForce "full";
}
