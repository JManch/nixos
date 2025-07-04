{
  vim.lsp = {
    enable = true;
    formatOnSave = true;
    mappings = {
      goToDeclaration = "<LEADER>lD";
      goToDefinition = "<LEADER>ld";
      goToType = "<LEADER>lt";
      listImplementations = "<LEADER>lm";
      listReferences = "<LEADER>lr";
      openDiagnosticFloat = "gl";
      nextDiagnostic = "]d";
      previousDiagnostic = "[d";
      documentHighlight = null;
      listDocumentSymbols = null;
      addWorkspaceFolder = null;
      removeWorkspaceFolder = null;
      listWorkspaceFolders = null;
      listWorkspaceSymbols = null;
      hover = "<LEADER>lH";
      signatureHelp = "<LEADER>lh";
      renameSymbol = "<LEADER>lR";
      codeAction = "<LEADER>la";
      format = "<LEADER>lf";
      toggleFormatOnSave = "<LEADER>lF";
    };
  };

  vim.diagnostics = {
    enable = true;
    config = {
      virtual_text = true;
      severity_sort = true;
      float.source = true;
      signs.text = {
        "vim.diagnostic.severity.ERROR" = "󰅚 ";
        "vim.diagnostic.severity.WARN" = "󰀪 ";
        "vim.diagnostic.severity.INFO" = "󰋽 ";
        "vim.diagnostic.severity.HINT" = "󰌶 ";
      };
    };
  };
}
