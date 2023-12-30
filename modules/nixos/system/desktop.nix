{ pkgs
, lib
, config
, ...
}:
let
  hyprland = (config.usrEnv.desktop.compositor == "hyprland");
  optional = lib.lists.optional;
in
lib.mkIf (config.usrEnv.desktop.enable) {
  services.xserver = {
    # Enable regardless of wayland for xwayland support
    enable = true;
    # Disable default login GUI
    displayManager.lightdm.enable = false;
  };

  # INFO: Hopefully this can be moved to home-manager once
  # https://github.com/nix-community/home-manager/pull/4707 is merged
  xdg.portal = {
    enable = true;
    wlr.enable = lib.validators.isWayland config;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
    ] ++ optional hyprland xdg-desktop-portal-hyprland;
    configPackages = optional hyprland pkgs.hyprland;
  };

  # Needed for swaylock authentication
  security.pam.services.swaylock = { };
}
