{ lib
, osConfig
, ...
}:
lib.mkIf osConfig.modules.programs.gaming.enable
{
  # Fix slow steam client downloads https://redd.it/16e1l4h
  home.file.".steam/steam/steam_dev.cfg".text = ''
    @nClientDownloadEnableHTTP2PlatformLinux 0
  '';
}
