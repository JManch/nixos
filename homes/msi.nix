{ lib, pkgs, ... }:
{
  home.packages = with pkgs; [
    libreoffice
    spotify
    discord
    chromium
  ];

  programs.firefox = {
    enable = true;
    profiles.default.settings = {
      "media.av1.enabled" = lib.mkForce false;
    };
  };

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
