{ lib, config }:
{
  enableOpt = false;
  fonts.fontconfig.enable = true;
  home.packages = [ config.${lib.ns}.desktop.style.font.package ];
  ns.persistence.directories = [ ".cache/fontconfig" ];
}
