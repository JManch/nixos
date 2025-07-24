{
  lib,
  pkgs,
  config,
  osConfig,
}:
let
  inherit (lib) ns optionalAttrs;
  cfg = config.${ns}.desktop.xdg;
  home = config.home.homeDirectory;
in
{
  enableOpt = false;

  # Many applications need this for xdg-open url opening however packages
  # rarely include is as a dependency for some reason
  home.packages = [ pkgs.xdg-utils ];

  # https://github.com/NixOS/nixpkgs/issues/160923
  # WARN: This only works if the necessary environment variables (most
  # importantly PATH and XDG_DATA_DIRS) have been imported using
  # dbus-update-activation-environment --systemd in the window-manager
  # start-up.
  xdg.portal.xdgOpenUsePortal = true;

  xdg.userDirs = {
    enable = true;
    createDirectories = true;
    extraConfig.XDG_SCREENSHOTS_DIR = "${home}/Pictures/Screenshots";
  }
  // optionalAttrs cfg.lowercaseUserDirs {
    desktop = "${home}/desktop";
    documents = "${home}/documents";
    download = "${home}/downloads";
    music = "${home}/music";
    pictures = "${home}/pictures";
    videos = "${home}/videos";
    templates = "${home}/templates";
    publicShare = "${home}/public";
    extraConfig.XDG_SCREENSHOTS_DIR = "${home}/pictures/screenshots";
  };

  xdg.mimeApps.enable = osConfig.${ns}.system.desktop.desktopEnvironment == null;

  ns.desktop.hyprland.settings.windowrule = [
    # Float the file picker
    "float, class:^(xdg-desktop-portal-gtk)$"
    "size 60% 60%, class:^(xdg-desktop-portal-gtk)$"
    "center, class:^(xdg-desktop-portal-gtk)$"
  ];
}
