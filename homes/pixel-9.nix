{ lib, ... }:
{
  ${lib.ns}.programs.shell = {
    enable = true;
    promptColor = "green";
    git.enable = true;
    neovim.enable = true;
    btop.enable = true;
    fastfetch.enable = true;
  };

  home.stateVersion = "24.05";
}
