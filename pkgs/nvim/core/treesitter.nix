{ lib, pkgs, ... }:
let
  inherit (lib) attrValues filterAttrs hasPrefix;
in
{
  vim.treesitter = {
    enable = true;
    autotagHtml = true;
    incrementalSelection.enable = false;
    addDefaultGrammars = false;

    # I don't think nvf supports vimPlugins.nvim-treesitter.withAllGrammars
    grammars = attrValues (
      filterAttrs (n: _: hasPrefix "tree-sitter-" n) pkgs.vimPlugins.nvim-treesitter.builtGrammars
    );

    indent.disable = [ "nix" ];
  };
}
