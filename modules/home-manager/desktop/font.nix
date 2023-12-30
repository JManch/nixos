{ lib
, config
, osConfig
, ...
}:
lib.mkIf osConfig.usrEnv.desktop.enable {
  fonts.fontconfig.enable = true;
  home.packages = [ config.modules.desktop.font.package ];
}
