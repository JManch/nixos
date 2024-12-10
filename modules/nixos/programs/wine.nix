{
  lib,
  pkgs,
  config,
  ...
}:
let
  inherit (config.${lib.ns}.system) desktop;
  cfg = config.${lib.ns}.programs.wine;
in
lib.mkIf (cfg.enable && desktop.enable) {
  userPackages = [
    cfg.package
    pkgs.winetricks
  ];

  environment.sessionVariables.WINEPREFIX = "$HOME/.local/share/wineprefixes/default";
  persistenceHome.directories = [ ".local/share/wineprefixes" ];
}
