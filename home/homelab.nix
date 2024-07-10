{
  modules = {
    shell = {
      enable = true;
      promptColor = "blue";
    };

    programs = {
      btop.enable = true;
      git.enable = true;
      neovim.enable = true;
      fastfetch.enable = true;
    };

    services = {
      syncthing = {
        enable = false;
        exposeWebGUI = true;
      };
    };
  };

  home.stateVersion = "24.05";
}
