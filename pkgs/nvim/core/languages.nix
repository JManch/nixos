{ lib, pkgs, ... }:
let
  inherit (lib) getExe mkForce generators;
in
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
      lsp.package = mkForce [ "rust-analyzer" ];
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
      extensions."typst-preview-nvim".setupOpts.dependencies_bin = {
        # Use shell tinymist instance
        "tinymist" = "tinymist";
        "websocat" = getExe pkgs.websocat;
      };
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

    haskell = {
      enable = true;
      lsp.enable = true;
      lsp.cmd = [
        "haskell-language-server-wrapper"
        "--lsp"
      ];
    };
  };

  # Typstyle will not automatically wrap to the line width by default
  vim.formatter.conform-nvim.setupOpts.formatters."typstyle".args = [ "--wrap-text" ];

  # We would rather use lsp server's from the local dev shell instead of
  # packing them all in our nvim derivation.
  vim.lsp.servers = {
    basedpyright.cmd = mkForce [
      "basedpyright-langserver"
      "--stdio"
    ];

    clangd.cmd = mkForce [ "clangd" ];

    cssls.cmd = mkForce [
      "vscode-css-language-server"
      "--stdio"
    ];

    gopls.cmd = mkForce [ "gopls" ];

    # Keep an eye on the cmd definiton here incase it changes
    # https://github.com/NotAShelf/nvf/blob/main/modules/plugins/languages/java.nix#L30
    "jdtls".cmd = generators.mkLuaInline ''
      {
        'jdtls',
        '-configuration',
        get_jdtls_config_dir(),
        '-data',
        get_jdtls_workspace_dir(),
        get_jdtls_jvm_args(),
      }
    '';

    lua-language-server.cmd = mkForce [ "lua-language-server" ];
    tinymist.cmd = mkForce [ "tinymist" ];

    ts_ls.cmd = mkForce [
      "typescript-language-server"
      "--stdio"
    ];
  };
}
