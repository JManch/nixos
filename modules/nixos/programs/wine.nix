{ lib, pkgs, config, ... }:
let
  inherit (lib) mkIf;
  cfg = config.modules.programs.wine;
in
mkIf (cfg.enable && config.usrEnv.desktop.enable)
{
  environment.systemPackages = [
    cfg.package
    pkgs.winetricks
  ];

  environment.sessionVariables.WINEPREFIX = "$HOME/.local/share/wineprefixes/default";
  persistenceHome.directories = [ ".local/share/wineprefixes" ];
}
