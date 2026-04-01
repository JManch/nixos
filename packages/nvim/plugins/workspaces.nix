{
  lib,
  pkgs,
  sources,
  ...
}:
let
  inherit (lib.nvim.binds) mkKeymap;
in
{
  vim.extraPlugins."workspaces.nvim" = {
    package = pkgs.vimUtils.buildVimPlugin {
      pname = "workspaces.nvim";
      version = "0-unstable-${sources."workspaces.nvim".revision}";
      src = sources."workspaces.nvim";
      meta.homepage = "https://github.com/natecraddock/workspaces.nvim";
    };

    setup = # lua
      ''
        local workspaces = require('workspaces')

        workspaces.setup {
          hooks = {
            open = function()
              vim.notify(
                'Loaded workspace ' .. workspaces.name(),
                vim.log.levels.INFO,
                { title = 'Workspaces', timeout = 1000 }
              )
            end,
          }
        }
      '';
  };

  vim.keymaps = [
    (mkKeymap "n" "<LEADER>w" "<CMD>WorkspacesOpen<CR>" { desc = "Open workspace"; })
  ];

  vim.lazy.plugins.fzf-lua.cmd = [ "WorkspacesOpen" ];
}
