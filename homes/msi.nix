{ lib, pkgs, ... }:
{
  home.packages = with pkgs; [
    libreoffice
    spotify
    discord
    chromium
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
      anki.enable = true;

      gaming = {
        mangohud.enable = true;
        prism-launcher.enable = true;
      };
    };

    backups.documents = {
      backend = "restic";
      paths = [ "Documents" ];
    };
  };

  home.stateVersion = "24.05";
}
