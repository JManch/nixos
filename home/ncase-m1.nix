{ inputs, pkgs, ... }:
{
  imports = [
    ./home.nix
    ./desktop
    ./shell
    ./programs/alacritty.nix
    ./programs/neovim
    ./programs/firefox.nix
    ./programs/cava.nix
    ./programs/btop.nix
    ./programs/git.nix
  ];

  home.packages = with pkgs; [
    spotify
    discord
  ];

  monitors = [
    {
      name = "DP-2";
      primary = true;
      refreshRate = 120;
      width = 2560;
      height = 1440;
      workspaces = [ "1" "3" "5" "7" "9" ];
    }
    {
      name = "HDMI-A-1";
      refreshRate = 59.951;
      width = 2560;
      height = 1440;
      workspaces = [ "2" "4" "6" "8" ];
    }
    {
      name = "DP-3";
      width = 2560;
      height = 1440;
      enabled = false;
    }
  ];
}
