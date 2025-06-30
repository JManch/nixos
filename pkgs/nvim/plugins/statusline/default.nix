{ pkgs, ... }:
{
  vim.extraPlugins."heirline.nvim" = {
    package = pkgs.vimPlugins.heirline-nvim;
    setup =
      # lua
      ''
        statusline = {
          setup = function()
            ${builtins.readFile ./statusline.lua}
          end
        }
        statusline.setup()
      '';
  };
}
