{
  lib,
  pkgs,
  config,
  ...
}:
let
  inherit (config.modules.system) desktop;
  cfg = config.modules.programs.wine;
in
lib.mkIf (cfg.enable && desktop.enable) {
  environment.systemPackages = [
    cfg.package
    pkgs.winetricks
  ];

  environment.sessionVariables.WINEPREFIX = "$HOME/.local/share/wineprefixes/default";
  persistenceHome.directories = [ ".local/share/wineprefixes" ];
}
