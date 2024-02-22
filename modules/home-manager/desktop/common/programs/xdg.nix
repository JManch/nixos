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

  # https://github.com/nix-community/home-manager/issues/4740
  home.sessionVariables.NIXOS_XDG_OPEN_USE_PORTAL = 1;

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
