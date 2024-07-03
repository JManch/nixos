{ pkgs, ... }:
{
  home.packages = with pkgs; [
    chromium
    discord
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

      gaming = {
        mangohud.enable = true;
        prism-launcher.enable = true;
      };
    };
  };
}
