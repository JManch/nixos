{
  imports = [
    ./eza.nix
    ./starship.nix
    ./fzf.nix
    ./zsh.nix
  ];

  home.sessionVariables = {
    COLORTERM = "truecolor";
  };
}
