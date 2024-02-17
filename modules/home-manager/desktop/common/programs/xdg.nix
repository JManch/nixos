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

  # TODO: Verify that every desktopEnvironment/windowManager really wants this
  # enabled (I doubt it)
  xdg.portal.enable = true;

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
