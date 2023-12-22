{ pkgs, ... }:
{
  imports = [
    ./eza.nix
    ./starship.nix
    ./fzf.nix
    ./zsh.nix
  ];

  home.packages = with pkgs; [
    tree
    wget
  ];

  home.sessionVariables = {
    COLORTERM = "truecolor";
  };
}
