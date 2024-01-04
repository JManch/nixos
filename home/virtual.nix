{
  imports = [
    ./core.nix
  ];

  modules = {
    desktop = {
      dunst.enable = true;
    };
    shell.enable = true;

    programs = {
      alacritty.enable = true;
      btop.enable = true;
      cava.enable = true;
      firefox.enable = true;
      git.enable = true;
      neovim.enable = true;
      fastfetch.enable = true;
    };
  };
}
