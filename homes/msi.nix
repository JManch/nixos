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
      multiviewerF1.enable = true;
      jellyfinMediaPlayer.enable = true;

      gaming = {
        mangohud.enable = true;
        prismLauncher.enable = true;
      };
    };

    backups.documents.paths = [ "Documents" ];
  };

  home.stateVersion = "24.05";
}
