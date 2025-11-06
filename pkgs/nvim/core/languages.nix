{ lib, pkgs, ... }:
{
  vim.languages = {
    enableTreesitter = true;

    nix = {
      enable = true;
      lsp.enable = true;
      lsp.server = "nil";

      format = {
        enable = true;
        package = pkgs.nixfmt-rfc-style;
        type = "nixfmt";
      };
    };

    lua = {
      enable = true;
      lsp.enable = true;
    };

    clang = {
      enable = true;
      lsp.enable = true;
    };

    rust = {
      enable = true;
      lsp.enable = true;
    };

    python = {
      enable = true;
      format.enable = true;
      lsp.enable = true;
    };

    go = {
      enable = true;
      lsp.enable = true;
    };

    java = {
      enable = true;
      lsp.enable = true;
      lsp.package = pkgs.jdt-language-server;
    };

    typst = {
      enable = true;
      lsp.enable = true;
      format.enable = true;
      format.type = "typstyle";
    };

    css = {
      enable = true;
      lsp.enable = true;
      format.enable = true;
    };

    ts = {
      enable = true;
      lsp.enable = true;
      format.enable = true;
    };
  };

  # The languages.nix module doesn't let us enable both nil and nixd so enable
  # nixd manually
  vim.lsp.lspconfig.sources.nix-lsp-nixd = ''
    lspconfig.nixd.setup{
      capabilities = capabilities,
      on_attach = attach_keymaps,
      cmd = { "${pkgs.nixd}/bin/nixd" },
    }
  '';

  # Typstyle will not automatically wrap to the line width by default
  vim.formatter.conform-nvim.setupOpts.formatters."typstyle".args = [ "--wrap-text" ];
}
