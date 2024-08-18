{ lib, pkgs, ... }@args:
{
  home.packages = with pkgs; [
    libreoffice
    spotify
    discord
    chromium
    netflix
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
      firefox.enable = false;
      firefox.backup = false;
      anki.enable = true;
      rnote.enable = true;
      multiviewerF1.enable = true;
      cava.enable = true;
      jellyfin-media-player.enable = true;

      gaming = {
        mangohud.enable = true;
        prism-launcher.enable = true;
      };
    };
  };

  # Use nightly until 130 releases for https://bugzilla.mozilla.org/show_bug.cgi?id=1898476
  programs.firefox.package = (lib.utils.flakePkgs args "firefox-nightly").firefox-nightly-bin;

  backups.documents.paths = [ "Documents" ];

  home.stateVersion = "24.05";
}
