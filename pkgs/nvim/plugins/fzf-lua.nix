{ lib, ... }:
let
  inherit (lib.nvim.binds) mkKeymap;
in
{
  vim.fzf-lua = {
    enable = true;
    profile = "telescope"; # investigate
    setupOpts = {
      files = {
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

      fzf_opts =
        let
          transformer = "echo -n change-preview-window: ; if ((100 * fzf_columns / fzf_lines >= 150)) && ((fzf_columns >= 120)); then; echo right; elif ((fzf_lines >= 40)); then; echo up; else; echo hidden; fi";
        in
        {
          # doesn't work for some reason
          # "--bind" = ''"start:transform(${transformer}),resize:transform(${transformer})"'';
          "--layout" = "reverse";
        };
    };
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
