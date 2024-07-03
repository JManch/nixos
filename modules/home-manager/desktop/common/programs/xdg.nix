{ lib
, pkgs
, config
, osConfig
, desktopEnabled
, ...
}:
let
  inherit (lib) mkIf optionalAttrs;
  cfg = config.modules.desktop.xdg;
  home = config.home.homeDirectory;
in
mkIf desktopEnabled
{
  # Many applications need this for xdg-open url opening however packages
  # rarely include is as a dependency for some reason
  home.packages = [ pkgs.xdg-utils ];

  # Only configure xdg-portal in home-manager if it is disabled in NixOS
  xdg.portal = mkIf (!osConfig.xdg.portal.enable) {
    enable = true;
    # https://github.com/NixOS/nixpkgs/issues/160923
    # WARN: This only works if the necessary environment variables (most
    # importantly PATH and XDG_DATA_DIRS) have been imported using
    # dbus-update-activation-environment --systemd in the window-manager
    # start-up.
    xdgOpenUsePortal = true;
  };

  xdg.userDirs = {
    enable = true;
    extraConfig.XDG_SCREENSHOTS_DIR = "${home}/pictures/screenshots";
  } // optionalAttrs cfg.lowercaseUserDirs {
    desktop = "${home}/desktop";
    documents = "${home}/documents";
    download = "${home}/downloads";
    music = "${home}/music";
    pictures = "${home}/pictures";
    videos = "${home}/videos";
  };

  xdg.mime.enable = true;
  xdg.mimeApps.enable = true;
}
