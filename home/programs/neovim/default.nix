{ config, pkgs, ... }:
{
  home.packages = with pkgs; [
    fd
  ];

  programs.ripgrep.enable = true;
  programs.fzf.enable = true;

  programs.neovim = {
    enable = true;
    # package = pkgs.neovim-nightly;
    vimAlias = true;
  };

  # xdg.configFile."nvim" = {
  #   source = config.lib.file.mkOutOfStoreSymlink ./nvim;
  #   recursive = true;
  # };
}
