{ lib, pkgs, config, ... }:
let
  cfg = config.modules.programs.wine;
in
lib.mkIf (cfg.enable && config.usrEnv.desktop.enable)
{
  environment.systemPackages = [
    cfg.package
    pkgs.winetricks
  ];

  environment.sessionVariables.WINEPREFIX = "$HOME/.local/share/wineprefixes/default";
  persistenceHome.directories = [ ".local/share/wineprefixes" ];
}
