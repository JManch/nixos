{ pkgs, ... }:
{
  vim.languages = {
    enableTreesitter = true;

    nix = {
      enable = true;

      format = {
        enable = true;
        package = pkgs.nixfmt-rfc-style;
        type = "nixfmt";
      };

      lsp = {
        enable = true;
        server = "nil";
      };
    };
  };
}
