{
  ns,
  lib,
  pkgs,
  config,
  selfPkgs,
  osConfig',
  ...
}:
let
  inherit (lib) mkIf;
  inherit (config.${ns}) desktop;
in
lib.mkIf (osConfig'.${ns}.programs.gaming.steam.enable or false) {
  # Native Linux version setup:
  # - Add non-steam game pointing to .local/share/Steam/steamapps/common/BeamNG.drive/BinLinux/BeamNG.drive.x64
  # - Set compatibilty tool to steam linux runtime 3.0
  ${ns}.programs.gaming = {
    gameClasses = [ "BeamNG\\.drive\\.x64" ];
    # Disable tearing in both the steam and linux version as it causes flashing
    # in the UI
    tearingExcludedClasses = [
      "steam_app_284160"
      "BeamNG\\.drive.x64"
    ];
  };

  home.packages = [ selfPkgs.beammp-launcher ];

  xdg.desktopEntries.beammp-launcher = mkIf desktop.enable {
    name = "BeamMP Launcher";
    exec = "xdg-terminal-exec --title=BeamMP -e BeamMP-Launcher --no-launch --no-update";
    settings.Path = "${config.xdg.dataHome}/BeamMP";
    terminal = false;
    type = "Application";
    icon = (
      pkgs.fetchurl {
        name = "beammp-icon.png";
        url = "https://avatars.githubusercontent.com/u/76395149";
        hash = "sha256-hogRsoB4l+pRh59QN6bNdUFHIP+d94HNwhTCftmhrp8=";
      }
    );
    categories = [ "Game" ];
  };

  # Just to create the .local/share/BeamMP dir
  xdg.dataFile."BeamMP/nix-placeholder".text = "";

  persistence.directories = [
    ".local/share/BeamNG.drive"
    ".local/share/BeamMP"
  ];
}
