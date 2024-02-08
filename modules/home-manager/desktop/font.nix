{ lib
, config
, osConfig
, ...
}:
lib.mkIf osConfig.usrEnv.desktop.enable {
  home.packages = [ config.modules.desktop.style.font.package ];

  fonts.fontconfig.enable = true;

  impermanence.directories = [
    ".cache/fontconfig"
  ];
}
