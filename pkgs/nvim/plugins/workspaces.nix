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
        -- Unfortunately there's no way to query the active tab so we have no
        -- way of restoring the original tab name after closing nvim
        -- https://github.com/zellij-org/zellij/issues/3090
        local update_zellij_tab = function(name)
          if not vim.env.ZELLIJ then return end
          vim.fn.jobstart({ "zellij", "action", "rename-tab", name }, { detach = true })
        end
        update_zellij_tab("nvim")

        local workspaces = require('workspaces')

        workspaces.setup {
          hooks = {
            open = function()
              update_zellij_tab("nvim: " .. workspaces.name())
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
