{
  lib,
  pkgs,
  config,
}:
{
  enableOpt = false;
  fonts.fontconfig.enable = true;

  home.packages = [
    config.${lib.ns}.desktop.style.font.package
    # For Chinese, Japanese, Korean fallback in electron apps
    pkgs.noto-fonts-cjk-sans
  ];

  ns.persistence.directories = [ ".cache/fontconfig" ];
}
