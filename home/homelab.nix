{
  modules = {
    shell.enable = true;

    programs = {
      btop.enable = true;
      git.enable = true;
      neovim.enable = true;
      fastfetch.enable = true;
    };

    services = {
      syncthing.enable = true;
    };
  };
}
