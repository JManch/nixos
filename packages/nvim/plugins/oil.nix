{ lib, pkgs, ... }:
{
  # Upstream module doesn't lazy load
  vim.lazy.plugins."oil.nvim" = {
    enabled = true;
    package = pkgs.vimPlugins.oil-nvim;
    lazy = true;
    setupModule = "oil";
    cmd = [ "Oil" ];
    keys = [
      (lib.nvim.binds.mkKeymap "n" "<LEADER>fd" "<CMD>Oil --float --preview<CR>" {
        desc = "oil.nvim browse files";
      })
    ];
    setupOpts = {
      float = {
        max_width = 0.8;
        max_height = 0.9;
      };

      win_options = {
        relativenumber = false;
        number = false;
      };

      use_default_keymaps = false;
      keymaps = lib.generators.mkLuaInline ''
        {
          ["g?"] = { "actions.show_help", mode = "n" },
          ["<CR>"] = "actions.select",
          ["<C-v>"] = { "actions.select", opts = { vertical = true } },
          ["<C-x>"] = { "actions.select", opts = { horizontal = true } },
          ["<C-t>"] = { "actions.select", opts = { tab = true } },
          ["<C-p>"] = "actions.preview",
          ["<ESC>"] = { "actions.close", mode = "n" },
          ["<C-l>"] = "actions.refresh",
          ["<S-h>"] = { "actions.parent", mode = "n" },
          ["<S-l>"] = { "actions.select", mode = "n" },
          ["-"] = { "actions.parent", mode = "n" },
          ["_"] = { "actions.open_cwd", mode = "n" },
          ["`"] = { "actions.cd", mode = "n" },
          ["~"] = { "actions.cd", opts = { scope = "tab" }, mode = "n" },
          ["gs"] = { "actions.change_sort", mode = "n" },
          ["gx"] = "actions.open_external",
          ["g."] = { "actions.toggle_hidden", mode = "n" },
        }
      '';

      view_options = {
        is_hidden_file = lib.generators.mkLuaInline ''
          function(name, bufnr)
            return name:match("^%.") and name ~= ".."
          end
        '';
      };
    };
  };
}
