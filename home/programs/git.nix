{ config, pkgs, ... }:
{
  programs.lazygit.enable = true;

  programs.git = {
    enable = true;
    userEmail = "JManch@protonmail.com";
    userName = "Joshua Manchester";
    extraConfig = {
      init.defaultBranch = "main";
      gpg.format = "ssh";
    };
    signing = {
      key = "${config.home.homeDirectory}/.ssh/id_ed25519";
      signByDefault = true;
    };
  };
}
