{
  imports = [
    ./completion.nix
    ./fzf-lua.nix
    ./languages.nix
    ./oil.nix
    ./treesitter.nix
  ];

  vim = {
    mini.icons.enable = true;

    visuals.indent-blankline = {
      enable = true;
      setupOpts = {
        indent.char = "│";
        scope.enabled = false;
      };
    };
  };
}
