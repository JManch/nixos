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
        enable = true;
        exposeWebGUI = true;
      };
    };
  };
}
