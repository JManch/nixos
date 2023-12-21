{ inputs, pkgs, ... }:
{
  imports = [
    ./home.nix
    ./shell
    ./programs/neovim
    ./programs/btop.nix
    ./programs/git.nix
  ];
}
