{ lib, ... }:
let
  inherit (lib.nvim.binds) mkKeymap;
in
{
  vim.fzf-lua = {
    enable = true;
    profile = "telescope";
    setupOpts = {
      winopts = {
        backdrop = 100;
        preview = {
          horizontal = "right:65%";
          layout = "horizontal";
          scrollbar = false;
        };
      };

      files = {
        # Unfortunately can't use fzfs dynamic --preview-window options
        previewer = lib.generators.mkLuaInline ''
          function()
            return vim.o.columns > 120 and "builtin" or false
          end
        '';
        cmd = "fd";
        fd_opts = "[[--color=never --type f --type l --exclude .git]]";
        hidden = false;
        cwd_prompt = false;
      };

      buffers = {
        previewer = false;
        winopts = {
          height = 0.23;
          width = 0.8;
          row = 0.5;
        };
      };

      fzf_opts."--layout" = "reverse";
    };
  };

  vim.lazy.plugins."fzf-lua" = {
    # we always use it on launch for workspace picker
    lazy = false;
    after =
      # lua
      ''
        require("fzf-lua").register_ui_select(function(ui_opts)
          ui_opts.winopts = {
            height = 15,
            width = 80,
            row = 0.45,
            col = 0.5,
          }
          return ui_opts
        end)
      '';
  };

  vim.luaConfigRC.basic = ''
    vim.env.FZF_DEFAULT_OPTS = nil
  '';

  vim.keymaps = [
    (mkKeymap "n" "<LEADER>ff" "<CMD>FzfLua files<CR>" { desc = "fzf-lua find files"; })
    (mkKeymap "n" "<LEADER>fa" "<CMD>FzfLua files no_ignore=true hidden=true<CR>" {
      desc = "fzf-lua find all files";
    })
    (mkKeymap "n" "<LEADER><LEADER>" "<CMD>FzfLua buffers<CR>" { desc = "fzf-lua buffers"; })
    (mkKeymap "n" "<LEADER>fg" "<CMD>FzfLua live_grep<CR>" { desc = "fzf-lua live grep cwd"; })
    (mkKeymap "n" "<LEADER>fG" "<CMD>FzfLua grep_cword<CR>" { desc = "fzf-lua grep current word"; })
    (mkKeymap "n" "<LEADER>fG" "<CMD>FzfLua grep_cword<CR>" { desc = "fzf-lua grep current word"; })
    (mkKeymap "n" "<LEADER>fb" "<CMD>FzfLua lgrep_curbuf<CR>" {
      desc = "fzf-lua live grep current buffer";
    })
    (mkKeymap "n" "<LEADER>fh" "<CMD>FzfLua helptags<CR>" { desc = "fzf-lua help tags"; })
    (mkKeymap "n" "<LEADER>fk" "<CMD>FzfLua keymaps<CR>" { desc = "fzf-lua keymaps"; })
    (mkKeymap "n" "<LEADER>fs" "<CMD>FzfLua spell_suggest<CR>" { desc = "fzf-lua spell suggest"; })
    (mkKeymap "n" "<LEADER>f<LEADER>" "<CMD>FzfLua resume<CR>" { desc = "fzf-lua resume last search"; })
    # TODO: Add extra telescope keymaps from old config
  ];
}
