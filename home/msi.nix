{ pkgs, ... }:
{
  home.packages = with pkgs; [
    chromium
    libreoffice
    spotify
  ];

  modules = {
    desktop = {
      enable = true;
      style.cursor = {
        enable = true;
        name = "Bibata-Modern-Ice";
      };
    };

    programs = {
      firefox.enable = true;
      anki.enable = true;
      rnote.enable = true;
      multiviewerF1.enable = true;
      cava.enable = true;
      discord.enable = true;

      gaming = {
        mangohud.enable = true;
        prism-launcher.enable = true;
      };
    };
  };

  backups.documents.paths = [ "documents" ];
}
