{ lib, config, osConfig, ... }:
lib.mkIf osConfig.modules.system.desktop.enable
{
  fonts.fontconfig.enable = true;

  home.packages = [ config.modules.desktop.style.font.package ];

  persistence.directories = [ ".cache/fontconfig" ];
}
