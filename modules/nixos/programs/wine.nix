{
  lib,
  cfg,
  pkgs,
}:
{
  opts.package = lib.mkPackageOption pkgs.wineWowPackages "stable" { };

  userPackages = [
    cfg.package
    pkgs.winetricks
  ];

  environment.sessionVariables.WINEPREFIX = "$HOME/.local/share/wineprefixes/default";

  persistenceHome.directories = [ ".local/share/wineprefixes" ];
}
