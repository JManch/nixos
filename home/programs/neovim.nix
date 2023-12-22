{pkgs, ...}: {
  home.packages = with pkgs; [
    # Tools
    fd
    # Language servers
    lua-language-server
    nil
    # Formatters
    stylua
    # nixpkgs-fmt
    alejandra
  ];

  programs.ripgrep.enable = true;
  programs.fzf.enable = true;

  programs.neovim = {
    enable = true;
    # package = pkgs.neovim-nightly;
    vimAlias = true;
  };

  home.sessionVariables.NIX_NEOVIM = 1;
  # xdg.configFile."nvim" = {
  #   source = config.lib.file.mkOutOfStoreSymlink ./nvim;
  #   recursive = true;
  # };
}
