{ lib, ... }:
{
  vim.git.gitsigns = {
    enable = true;
    setupOpts.on_attach =
      lib.generators.mkLuaInline
        # lua
        ''
          function(bufnr)
            local gitsigns = require('gitsigns')

            local map = function(mode, l, r, desc, opts)
              opts = opts or {}
              opts.desc = desc
              opts.buffer = bufnr
              vim.keymap.set(mode, l, r, opts)
            end

            map('n', ']c', function()
              if vim.wo.diff then
                vim.cmd.normal({']c', bang = true})
              else
                gitsigns.nav_hunk('next')
              end
            end, 'Gitsigns next hunk')

            map('n', '[c', function()
              if vim.wo.diff then
                vim.cmd.normal({'[c', bang = true})
              else
                gitsigns.nav_hunk('prev')
              end
            end, 'Gitsigns previous hunk')

            map('v', '<leader>hs', function()
              gitsigns.stage_hunk({ vim.fn.line('.'), vim.fn.line('v') })
            end, 'Gitsigns stage hunk')
            map('v', '<leader>hr', function()
              gitsigns.reset_hunk({ vim.fn.line('.'), vim.fn.line('v') })
            end, 'Gitsigns reset hunk')
            map('n', '<LEADER>hp', gitsigns.preview_hunk, 'Gitsigns preview hunk')
            map('n', '<LEADER>hb', function() gitsigns.blame_line({ full = true }) end, 'Gitsigns blame line')
            map('n', '<LEADER>ht', gitsigns.toggle_word_diff, 'Gitsigns toggle word diff')
            map('n', '<LEADER>hd', gitsigns.diffthis, 'Gitsigns view index file diff')
          end
        '';
  };
}
