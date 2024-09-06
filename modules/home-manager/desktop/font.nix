{
  ns,
  lib,
  config,
  desktopEnabled,
  ...
}:
lib.mkIf desktopEnabled {
  fonts.fontconfig.enable = true;

  home.packages = [ config.${ns}.desktop.style.font.package ];

  persistence.directories = [ ".cache/fontconfig" ];
}
