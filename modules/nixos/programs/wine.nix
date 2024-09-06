{
  ns,
  lib,
  pkgs,
  config,
  ...
}:
let
  inherit (config.${ns}.system) desktop;
  cfg = config.${ns}.programs.wine;
in
lib.mkIf (cfg.enable && desktop.enable) {
  userPackages = [
    cfg.package
    pkgs.winetricks
  ];

  environment.sessionVariables.WINEPREFIX = "$HOME/.local/share/wineprefixes/default";
  persistenceHome.directories = [ ".local/share/wineprefixes" ];
}
