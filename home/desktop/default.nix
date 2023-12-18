{ pkgs, ... }:
{
  imports = [
    ./hyprland.nix
    ./waybar.nix
    ./anyrun.nix
    ./font.nix
  ];

  home.packages = with pkgs; [
    wl-clipboard
  ];

  home.sessionVariables.NIXOS_OZONE_WL = "1";
}
