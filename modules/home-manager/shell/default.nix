{ lib, ... }: {
  imports = [
    ./eza.nix
    ./starship.nix
    ./fzf.nix
    ./zsh.nix
  ];

  options.modules.shell = {
    enable = lib.mkEnableOption "enable custom shell";
  };
}
