{ lib
, config
, nixosConfig
, ...
}:
lib.mkIf nixosConfig.usrEnv.desktop.enable {
  home.packages = [ config.modules.desktop.font.package ];

  fonts.fontconfig.enable = true;

  impermanence.directories = [
    ".cache/fontconfig"
  ];
}
