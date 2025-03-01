{
  lib,
  cfg,
  pkgs,
}:
{
  opts.package = lib.mkPackageOption pkgs.wineWowPackages "stable" { };

  ns.userPackages = [
    cfg.package
    pkgs.winetricks
  ];

  environment.sessionVariables.WINEPREFIX = "$HOME/.local/share/wineprefixes/default";

  ns.persistenceHome.directories = [ ".local/share/wineprefixes" ];
}
