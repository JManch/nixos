{ lib, ... }:
{
  ${lib.ns}.programs.shell = {
    enable = true;
    promptColor = "green";
    git.enable = true;
    neovim.enable = true;
    btop.enable = false; # doesn't work
    fastfetch.enable = true;
    taskwarrior.enable = true;
  };

  home.stateVersion = "24.05";
}
