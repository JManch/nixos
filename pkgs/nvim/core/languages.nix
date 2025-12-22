{ lib, ... }:
{
  vim.languages = {
    enableTreesitter = true;

    nix = {
      enable = true;
      lsp.enable = true;
      lsp.servers = [
        "nil"
        "nixd"
      ];
      format.enable = true;
      format.type = [ "nixfmt" ];
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
    };

    typst = {
      enable = true;
      lsp.enable = true;
      format.enable = true;
      format.type = [ "typstyle" ];
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

  # Typstyle will not automatically wrap to the line width by default
  vim.formatter.conform-nvim.setupOpts.formatters."typstyle".args = [ "--wrap-text" ];

  vim.lsp.servers = {
    "jdtls".cmd = lib.generators.mkLuaInline ''
      {
        'jdtls',
        '-configuration',
        get_jdtls_config_dir(),
        '-data',
        get_jdtls_workspace_dir(),
        get_jdtls_jvm_args(),
      }
    '';
  };
}
