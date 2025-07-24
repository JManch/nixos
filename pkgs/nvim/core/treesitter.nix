{ pkgs, ... }:
{
  vim.treesitter = {
    enable = true;
    autotagHtml = true;
    incrementalSelection.enable = false;
    addDefaultGrammars = false;
    grammars = pkgs.vimPlugins.nvim-treesitter.allGrammars;
    indent.disable = [ "nix" ];
  };
}
