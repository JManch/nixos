{ lib, ... }:
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
      hover = "<LEADER>lh";
      signatureHelp = "<LEADER>lH";
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

  vim.luaConfigRC.commands =
    lib.nvim.dag.entryBefore [ "mappings" ] # lua
      ''
        if vim.fn.exists(':lsp') == 2 then
          print("I can remove the Lsp* commands now as they should have native implementations in nvim 0.12")
        end

        vim.api.nvim_create_user_command('LspInfo', ':checkhealth vim.lsp', { desc = 'Alias to `:checkhealth vim.lsp`' })

        -- Code copied from nvim-lspconfig
        -- https://github.com/neovim/nvim-lspconfig/blob/master/LICENSE.md
        local complete_client = function(arg)
          return vim
            .iter(vim.lsp.get_clients())
            :map(function(client)
              return client.name
            end)
            :filter(function(name)
              return name:sub(1, #arg) == arg
            end)
            :totable()
        end

        local complete_config = function(arg)
          return vim
            .iter(vim.api.nvim_get_runtime_file(('lsp/%s*.lua'):format(arg), true))
            :map(function(path)
              local file_name = path:match('[^/]*.lua$')
              return file_name:sub(0, #file_name - 4)
            end)
            :totable()
        end

        vim.api.nvim_create_user_command('LspStart', function(info)
          local servers = info.fargs

          -- Default to enabling all servers matching the filetype of the current buffer.
          -- This assumes that they've been explicitly configured through `vim.lsp.config`,
          -- otherwise they won't be present in the private `vim.lsp.config._configs` table.
          if #servers == 0 then
            local filetype = vim.bo.filetype
            for name, _ in pairs(vim.lsp.config._configs) do
              local filetypes = vim.lsp.config[name].filetypes
              if filetypes and vim.tbl_contains(filetypes, filetype) then
                table.insert(servers, name)
              end
            end
          end

          vim.lsp.enable(servers)
        end, {
          desc = 'Enable and launch a language server',
          nargs = '?',
          complete = complete_config,
        })

        vim.api.nvim_create_user_command('LspRestart', function(info)
          local client_names = info.fargs

          -- Default to restarting all active servers
          if #client_names == 0 then
            client_names = vim
              .iter(vim.lsp.get_clients())
              :map(function(client)
                return client.name
              end)
              :totable()
          end

          for name in vim.iter(client_names) do
            if vim.lsp.config[name] == nil then
              vim.notify(("Invalid server name '%s'"):format(name))
            else
              vim.lsp.enable(name, false)
              if info.bang then
                vim.iter(vim.lsp.get_clients({ name = name })):each(function(client)
                  client:stop(true)
                end)
              end
            end
          end

          local timer = assert(vim.uv.new_timer())
          timer:start(500, 0, function()
            for name in vim.iter(client_names) do
              vim.schedule_wrap(vim.lsp.enable)(name)
            end
          end)
        end, {
          desc = 'Restart the given client',
          nargs = '?',
          bang = true,
          complete = complete_client,
        })

        vim.api.nvim_create_user_command('LspStop', function(info)
          local client_names = info.fargs

          -- Default to disabling all servers on current buffer
          if #client_names == 0 then
            client_names = vim
              .iter(vim.lsp.get_clients())
              :map(function(client)
                return client.name
              end)
              :totable()
          end

          for name in vim.iter(client_names) do
            if vim.lsp.config[name] == nil then
              vim.notify(("Invalid server name '%s'"):format(name))
            else
              vim.lsp.enable(name, false)
              if info.bang then
                vim.iter(vim.lsp.get_clients({ name = name })):each(function(client)
                  client:stop(true)
                end)
              end
            end
          end
        end, {
          desc = 'Disable and stop the given client',
          nargs = '?',
          bang = true,
          complete = complete_client,
        })
      '';
}
