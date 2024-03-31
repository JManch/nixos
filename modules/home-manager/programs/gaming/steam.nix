{ lib
, pkgs
, config
, osConfig
, ...
}:
let
  inherit (lib) mkIf getExe';
  cfg = osConfig.modules.programs.gaming.steam;
in
mkIf cfg.enable
{
  # Fix slow steam client downloads https://redd.it/16e1l4h
  home.file.".steam/steam/steam_dev.cfg".text = ''
    @nClientDownloadEnableHTTP2PlatformLinux 0
  '';

  modules.programs.gaming = {
    gameClasses = [
      "steam_app.*"
      "cs2"
    ];

    tearingExcludedClasses = [
      "steam_app_1174180" # RDR2 - half-vsync without tearing is preferrable
    ];
  };

  desktop.hyprland.settings.windowrulev2 = [
    # Main steam window
    "workspace 5,class:^(steam)$,title:^(Steam)$"

    # Steam sign-in window
    "noinitialfocus,class:^(steam)$,title:^(Sign in to Steam)$"
    "workspace 5 silent,class:^(steam)$,title:^(Sign in to Steam)$"

    # Friends list
    "float,class:^(steam)$,title:^(Friends List)$"
    "size 360 700,class:^(steam)$,title:^(Friends List)$"
    "center,class:^(steam)$,title:^(Friends List)$"
  ];

  programs.zsh.shellAliases = {
    beam-mp = "${getExe' pkgs.protontricks "protontricks-launch"} --appid 284160 ${config.home.homeDirectory}/.local/share/Steam/steamapps/compatdata/284160/pfx/dosdevices/c:/users/steamuser/AppData/Roaming/BeamMP-Launcher/BeamMP-Launcher.exe";
  };
}
