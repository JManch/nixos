{ lib
, pkgs
, config
, osConfig
, ...
}:
lib.mkIf osConfig.usrEnv.desktop.enable
{
  # Many applications need this for xdg-open url opening however package
  # managers rarely include is as a dependency for some reason
  home.packages = [ pkgs.xdg-utils ];

  # TODO: Verify that every desktopEnvironment/windowManager really wants this enabled (I doubt it)
  xdg.portal.enable = true;

  xdg.userDirs = {
    enable = true;
    desktop = "${config.home.homeDirectory}/desktop";
    documents = "${config.home.homeDirectory}/documents";
    download = "${config.home.homeDirectory}/downloads";
    music = "${config.home.homeDirectory}/music";
    pictures = "${config.home.homeDirectory}/pictures";
    videos = "${config.home.homeDirectory}/videos";
  };

  xdg.mime.enable = true;
  xdg.mimeApps = {
    enable = true;
  };
}
