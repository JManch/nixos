{ lib
, pkgs
, config
, osConfig
, ...
}:
lib.mkIf osConfig.usrEnv.desktop.enable
{
  # Many applications need this for xdg-open url opening however packages
  # rarely include is as a dependency for some reason
  home.packages = [ pkgs.xdg-utils ];

  xdg.portal = {
    enable = true;
    # https://github.com/NixOS/nixpkgs/issues/160923
    # WARN: This only works if the necessary environment variables (most
    # importantly PATH and XDG_DATA_DIRS) have been imported using
    # dbus-update-activation-environment --systemd in the window-manager
    # start-up.
    xdgOpenUsePortal = true;
  };

  xdg.userDirs = let home = config.home.homeDirectory; in {
    enable = true;
    desktop = "${home}/desktop";
    documents = "${home}/documents";
    download = "${home}/downloads";
    music = "${home}/music";
    pictures = "${home}/pictures";
    videos = "${home}/videos";
  };

  xdg.mime.enable = true;

  xdg.mimeApps = {
    enable = true;
  };
}
