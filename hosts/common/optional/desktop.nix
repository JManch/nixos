{ pkgs, ... }:
{
  services.xserver = {
    enable = true;
    displayManager.lightdm.enable = false;
  };

  # INFO: Hopefully this can be moved to home-manager once
  # https://github.com/nix-community/home-manager/pull/4707 is merged
  xdg.portal = {
    enable = true;
    wlr.enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-hyprland
      xdg-desktop-portal-gtk
    ];
    configPackages = [ pkgs.hyprland ];
  };
}
