{ pkgs, ... }:
{
  vim.treesitter = {
    enable = true;
    autotagHtml = true;
    addDefaultGrammars = false;
    grammars = pkgs.vimPlugins.nvim-treesitter.allGrammars;
  };
}
