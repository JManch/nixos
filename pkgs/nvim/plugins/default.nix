{ pkgs, sources, ... }:
{
  imports = [
    ./completion.nix
    ./fzf-lua.nix
    ./oil.nix
    ./color-scheme.nix
    ./dashboard.nix
    ./workspaces.nix
    ./gitsigns.nix
    ./textobjs.nix
    ./statusline
    ./terminal.nix
  ];

  vim = {
    mini.pairs.enable = true;
    visuals.fidget-nvim.enable = true;
    visuals.nvim-web-devicons.enable = true;

    notify.nvim-notify = {
      enable = true;
      # nvf position option is wrong
      setupOpts.top_down = false;
    };

    mini.surround = {
      enable = true;
      setupOpts = {
        highlight_duration = 2000;
        mappings = {
          add = "<LEADER>aa";
          delete = "<LEADER>ad";
          find = "<LEADER>af";
          find_left = "<leader>aF";
          highlight = "<LEADER>ah";
          replace = "<LEADER>ar";
          update_n_line = "<LEADER>an";
        };
      };
    };

    # nvf module is overcomplicated
    extraPlugins."leap.nvim" = {
      package = pkgs.vimPlugins.leap-nvim;
      setup = ''
        require('leap').add_default_mappings()
      '';
    };

    extraPlugins."indentmini.nvim" = {
      package = pkgs.vimUtils.buildVimPlugin {
        pname = "indentmini.nvim";
        version = "0-unstable-${sources."indentmini.nvim".revision}";
        src = sources."indentmini.nvim";
        meta.homepage = "https://github.com/nvimdev/indentmini.nvim";
      };
      setup =
        # lua
        ''
          vim.api.nvim_set_hl(0, "IndentLine", { link = "LineNr" })
          vim.api.nvim_set_hl(0, "IndentLineCurrent", { link = "LineNr" })
          vim.api.nvim_create_autocmd("ColorScheme", {
            group = vim.api.nvim_create_augroup("IndentMini", {}),
            pattern = "*",
            desc = "Link indentmini highlight groups",
            callback = function()
              vim.api.nvim_set_hl(0, "IndentLine", { link = "LineNr" })
              vim.api.nvim_set_hl(0, "IndentLineCurrent", { link = "LineNr" })
            end,
          })
          require("indentmini").setup()
        '';
    };

    lazy.plugins."tabular" = {
      enabled = true;
      package = pkgs.vimPlugins.tabular;
      lazy = true;
      cmd = [ "Tabularize" ];
    };
  };
}
