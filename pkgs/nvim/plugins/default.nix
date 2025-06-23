{ pkgs, ... }:
{
  imports = [
    ./completion.nix
    ./fzf-lua.nix
    ./languages.nix
    ./oil.nix
    ./treesitter.nix
    ./color-scheme.nix
    ./dashboard.nix
    ./workspaces.nix
    ./gitsigns.nix
    ./textobjs.nix
  ];

  vim = {
    mini.pairs.enable = true;
    visuals.fidget-nvim.enable = true;

    visuals.indent-blankline = {
      enable = true;
      setupOpts = {
        indent.char = "│";
        scope.enabled = false;
        exclude.filetypes = [ "dashboard" ];
      };
    };

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

    lazy.plugins."tabular" = {
      enabled = true;
      package = pkgs.vimPlugins.tabular;
      lazy = true;
      cmd = [ "Tabularize" ];
    };
  };
}
