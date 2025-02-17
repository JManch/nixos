{ lib, ... }:
{
  ${lib.ns}.programs.shell = {
    enable = true;
    atuin.enable = true;
    promptColor = "blue";
    btop.enable = true;
    git.enable = true;
    neovim.enable = true;
    fastfetch.enable = true;
  };

  home.stateVersion = "24.05";
}
