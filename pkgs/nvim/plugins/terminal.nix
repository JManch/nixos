{ lib, pkgs, ... }:
let
  inherit (lib.nvim.binds) mkKeymap;
in
{
  vim.lazy.plugins."terminal.nvim" = {
    enabled = true;
    package = pkgs.vimPlugins.terminal-nvim;
    lazy = true;
    setupModule = "terminal";
    cmd = [ "Lazygit" ];
    keys = [
      (mkKeymap "n" "<LEADER>lg" "<CMD>Lazygit<CR>" { desc = "Open lazygit"; })
    ];
    after = # lua
      ''
        local lazygit = require('terminal').terminal:new({
          layout = { open_cmd = 'float', height = 0.9, width = 0.9, border = 'single' },
          cmd = { 'lazygit' },
          autoclose = true,
        })
        vim.env["GIT_EDITOR"] = "nvr -cc close -cc split --remote-wait +'set bufhidden=wipe'"
        vim.api.nvim_create_user_command('Lazygit', function(args)
          lazygit.cwd = args.args and vim.fn.expand(args.args)
          lazygit:toggle(nil, true)
        end, { nargs = '?' })

        local terminal_group = vim.api.nvim_create_augroup('Terminal', {})
        vim.api.nvim_create_autocmd({ "WinEnter", "BufWinEnter", "TermOpen" }, {
          group = terminal_group,
          callback = function(args)
            if vim.startswith(vim.api.nvim_buf_get_name(args.buf), "term://") then
              vim.cmd.startinsert()
            end
          end,
        })
      '';
  };
}
