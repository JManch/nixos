{ lib, pkgs, ... }:
let
  inherit (lib.nvim.binds) mkKeymap;
in
{
  vim.treesitter = {
    enable = true;
    autotagHtml = true;
    addDefaultGrammars = false;
    grammars = pkgs.vimPlugins.nvim-treesitter.allGrammars;
  };

  vim.keymaps = [
    (mkKeymap [ "x" "o" ] "ah"
      ''
        function()
          if vim.treesitter.get_parser(nil, nil, { error = false }) then
            require('vim.treesitter._select').select_parent(vim.v.count1)
          else
            vim.lsp.buf.selection_range(vim.v.count1)
          end
        end
      ''
      {
        lua = true;
        desc = "Select parent treesitter node or outer incremental lsp selections";
      }
    )

    (mkKeymap [ "x" "o" ] "ih"
      ''
        function()
          if vim.treesitter.get_parser(nil, nil, { error = false }) then
            require('vim.treesitter._select').select_child(vim.v.count1)
          else
            vim.lsp.buf.selection_range(-vim.v.count1)
          end
        end
      ''
      {
        lua = true;
        desc = "Select child treesitter node or inner incremental lsp selections";
      }
    )
  ];
}
