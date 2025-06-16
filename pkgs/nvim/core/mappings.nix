{ lib, ... }:
let
  inherit (lib.nvim.binds) mkKeymap;
in
{
  vim.keymaps = [
    (mkKeymap "i" "jk" "<ESC>" { desc = "Exit insert mode"; })
    (mkKeymap "i" "<C-b>" "<ESC>^i" { desc = "Jump to beginning of line"; })
    (mkKeymap "i" "<C-e>" "<END>" { desc = "Jump to end of line"; })
    (mkKeymap "i" "<S-Tab>" "jump_out" {
      lua = true;
      desc = "Jump out of things";
    })

    (mkKeymap "n" "<C-h>" "<C-w>h" { desc = "Go to the left window"; })
    (mkKeymap "n" "<C-l>" "<C-w>l" { desc = "Go to the right window"; })
    (mkKeymap "n" "<C-j>" "<C-w>j" { desc = "Go to the down window"; })
    (mkKeymap "n" "<C-k>" "<C-w>k" { desc = "Go to the up window"; })

    (mkKeymap "n" "<S-j>" "<C-o>" { desc = "Go to old cursor position"; })
    (mkKeymap "n" "<S-k>" "<C-i>" { desc = "Go to newer cursor position"; })

    (mkKeymap "n" "]q" "<CMD>cn<CR>" { desc = "Go to next item in quickfix list"; })
    (mkKeymap "n" "[q" "<CMD>cp<CR>" { desc = "Go to previous item in quickfix list"; })

    (mkKeymap "n" "vv" "vg_" { desc = "Visual select to last character"; })

    (mkKeymap "n" "<S-e>" "ge" { desc = "Go to end of previous word"; })

    (mkKeymap [ "n" "v" "o" ] "<S-h>" "^" { desc = "Go first non-blank character"; })
    (mkKeymap [ "n" "v" "o" ] "<S-l>" "g_" { desc = "Go to last non-blank character"; })

    (mkKeymap "n" "<C-d>" "<C-d>zz" { desc = "Scroll down half a page and centre cursor"; })
    (mkKeymap "n" "<C-u>" "<C-u>zz" { desc = "Scroll up half a page and centre cursor"; })
    (mkKeymap "n" "<C-o>" "<C-o>zz" { desc = "Go to prev marker and centre cursor"; })
    (mkKeymap "n" "<C-i>" "<C-i>zz" { desc = "Go to next marker and centre cursor"; })

    (mkKeymap "n" "<LEADER>v" "<CMD>vsplit<CR><C-l>" { desc = "Vertical split current buffer"; })
    (mkKeymap "n" "<S-x>" "<CMD>Bwipeout<CR>" { desc = "Close current buffer"; })

    (mkKeymap "n" "<LEADER>y" "\"+y" { desc = "Yank to system register"; })
    (mkKeymap "n" "<LEADER>Y" "\"+y$" { desc = "Yank till end of line to system register"; })
    (mkKeymap "n" "<LEADER>p" "\"+p" { desc = "Put from system register"; })
    (mkKeymap "n" "<LEADER>P" "\"+P" { desc = "Put before from system register"; })

    (mkKeymap "n" "<LEADER>o" "o<ESC>" { desc = "Create new line below"; })
    (mkKeymap "n" "<LEADER>O" "O<ESC>" { desc = "Create new line above"; })

    (mkKeymap "n" "<LEADER>c" "<CMD>nohl<CR>" { desc = "Clear search highlighting"; })

    (mkKeymap "n" "<LEADER>l" "<CMD>SunsetToggle<CR>" { desc = "Toggle sunset theme"; })
    (mkKeymap "n" "<LEADER>n" "<CMD>ToggleCMDHeight<CR>" { desc = "Toggle cmdheight"; })

    (mkKeymap "n" "die" "diwx" { desc = "Extended deleted inner word"; })

    (mkKeymap "v" "<LEADER>y" "\"+y" { desc = "Yank to system register"; })
    (mkKeymap "v" "<LEADER>p" "\"+p" { desc = "Put from system register"; })
    (mkKeymap "v" "<LEADER>P" "\"+P" { desc = "Put before from system register"; })

    (mkKeymap "v" "gy" "ygv<ESC>" { desc = "Yank and maintain cursor position"; })

    (mkKeymap "v" ">" ">gv" { desc = "Indent right and maintain highlight"; })
    (mkKeymap "v" "<" "<gv" { desc = "Indent left and maintain highlight"; })

    (mkKeymap "v" "<S-j>" ":m '>+1<CR>gv==kgvo<ESC>=kgvo" { desc = "Move selected text down"; })
    (mkKeymap "v" "<S-k>" ":m '<-2<CR>gv==jgvo<ESC>=jgvo" { desc = "Move selected text up"; })
    (mkKeymap "v" "<S-m>" "<S-j>" { desc = "Merge selected lines into one line"; })
  ];

  vim.luaConfigRC.functionsForMappings =
    lib.nvim.dag.entryBefore [ "mappings" ]
      # lua
      ''
        local jump_chars = {
          ['('] = true,
          [')'] = true,
          ['['] = true,
          [']'] = true,
          ['{'] = true,
          ['}'] = true,
          ['"'] = true,
          ["'"] = true,
          ['`'] = true,
          ['<'] = true,
          ['>'] = true,
          [','] = true,
          ['.'] = true,
        }

        local jump_out = function()
          local cur_pos = vim.api.nvim_win_get_cursor(0)
          local row = cur_pos[1]
          local col = cur_pos[2]

          local line = vim.api.nvim_get_current_line()
          local sub_line = line:sub(col + 1, #line)

          local jumped = false
          for c in sub_line:gmatch('.') do
            col = col + 1
            if jump_chars[c] then
              jumped = true
              vim.api.nvim_win_set_cursor(0, { row, col })
              break
            end
          end
          if not jumped then
            vim.api.nvim_win_set_cursor(0, { row, #line })
          end
        end
      '';
}
