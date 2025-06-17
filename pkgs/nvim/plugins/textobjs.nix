{ lib, pkgs, ... }:
let
  inherit (lib.nvim.binds) mkKeymap;
in
{
  vim.lazy.plugins."nvim-various-textobjs" = {
    enabled = true;
    package = pkgs.vimPlugins.nvim-various-textobjs;
    keys = [
      (mkKeymap [ "o" "x" ] "iS" "function() require('various-textobjs').subword('inner') end" {
        desc = "Select inner subword";
        lua = true;
      })

      (mkKeymap [ "o" "x" ] "aS" "function() require('various-textobjs').subword('outer') end" {
        desc = "Select outer subword";
        lua = true;
      })

      (mkKeymap [ "o" "x" ] "in" "function() require('various-textobjs').number('inner') end" {
        desc = "Select inner number";
        lua = true;
      })

      (mkKeymap [ "o" "x" ] "an" "function() require('various-textobjs').number('outer') end" {
        desc = "Select outer number";
        lua = true;
      })
    ];
  };
}
