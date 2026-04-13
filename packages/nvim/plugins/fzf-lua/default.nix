{ lib, pkgs, ... }:
let
  inherit (lib.nvim.binds) mkKeymap;
in
{
  # nvf module doesn't provide anything and uses lazy which we don't want as
  # we also use fzf-lua on launch for workspace switching. Also this plugin
  # is a nightmare to setup with Nix.
  vim.extraPlugins."fzf-lua" = {
    package = pkgs.vimPlugins.fzf-lua;
    setup = "dofile('${
      pkgs.replaceVars ./fzf-lua.lua {
        fzf_bin = lib.getExe pkgs.fzf;
      }
    }')";
  };

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
    (mkKeymap "n" "<LEADER>fr<LEADER>" "<CMD>FzfLua registers<CR>" { desc = "fzf-lua registers"; })
    (mkKeymap "n" "<LEADER>fj<LEADER>" "<CMD>FzfLua jumps<CR>" { desc = "fzf-lua jumps"; })
    (mkKeymap "n" "<LEADER>fu<LEADER>" "<CMD>FzfLua undotree<CR>" { desc = "fzf-lua undotree"; })
    (mkKeymap "n" "<LEADER>fp<LEADER>" "<CMD>FzfLua complete_path<CR>" {
      desc = "fzf-lua complete path";
    })

    (mkKeymap "n" "<LEADER>gl" "<CMD>FzfLua git_reflog<CR>" { desc = "fzf-lua git reflog"; })
    (mkKeymap "n" "<LEADER>gc" "<CMD>FzfLua git_commits<CR>" { desc = "fzf-lua git commit history"; })
    (mkKeymap "n" "<LEADER>gC" "<CMD>FzfLua git_bcommits<CR>" {
      desc = "fzf-lua git buffer commit history";
    })
    (mkKeymap "n" "<LEADER>gb" "<CMD>FzfLua git_blame<CR>" { desc = "fzf-lua git blame"; })
    # TODO: Add extra telescope keymaps from old config
  ];

}
