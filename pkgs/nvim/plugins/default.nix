{
  imports = [
    ./completion.nix
    ./fzf-lua.nix
    ./languages.nix
    ./oil.nix
    ./treesitter.nix
    ./colorscheme.nix
    ./dashboard.nix
    ./workspaces.nix
    ./gitsigns.nix
  ];

  vim = {
    mini.pairs.enable = true;

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
      setupOpts.position = "bottom_right";
    };
  };
}
