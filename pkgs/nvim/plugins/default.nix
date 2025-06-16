{
  imports = [
    ./completion.nix
    ./fzf-lua.nix
    ./languages.nix
    ./oil.nix
    ./treesitter.nix
    ./colorscheme.nix
  ];

  vim = {
    visuals.indent-blankline = {
      enable = true;
      setupOpts = {
        indent.char = "│";
        scope.enabled = false;
      };
    };

    notify.nvim-notify = {
      enable = true;
      setupOpts.position = "top_right";
    };
  };
}
