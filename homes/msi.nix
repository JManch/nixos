{ lib, pkgs, ... }:
{
  home.packages = with pkgs; [
    libreoffice
    spotify
    discord
    chromium
    netflix
  ];

  ${lib.ns} = {
    desktop = {
      enable = true;
      style.cursor = {
        enable = true;
        name = "Bibata-Modern-Ice";
      };
    };

    programs.desktop = {
      firefox.enable = false;
      firefox.backup = false;
      anki.enable = true;
      rnote.enable = true;
      multiviewer-f1.enable = true;
      jellyfin-media-player.enable = true;

      gaming = {
        mangohud.enable = true;
        prism-launcher.enable = true;
      };
    };

    backups.documents.paths = [ "Documents" ];
  };

  home.stateVersion = "24.05";
}
