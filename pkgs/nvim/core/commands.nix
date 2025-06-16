{ lib, ... }:
{
  vim.luaConfigRC.functionsForCommands =
    lib.nvim.dag.entryBefore [ "commands" ]
      # lua
      ''
        local toggle_table_key = function(table, key, on, off)
          if table[key] ~= off then
            table[key] = off
          else
            table[key] = on
          end
        end

        local toggle_g = function(key, on, off) toggle_table_key(vim.g, key, on, off) end
        local toggle_o = function(key, on, off) toggle_table_key(vim.o, key, on, off) end
        local toggle_wo = function(key, on, off) toggle_table_key(vim.wo, key, on, off) end
        local toggle_local_opt = function(key, value)
          if vim.opt_local[key]:get()[value] == nil then
            vim.opt_local[key]:append(value)
          else
            vim.opt_local[key]:remove(value)
          end
        end
      '';

  vim.luaConfigRC.commands =
    lib.nvim.dag.entryBefore [ "mappings" ]
      # lua
      ''
        vim.api.nvim_create_user_command("ToggleColorcolumn", function() toggle_wo("colorcolumn", "80", "") end, {})
        vim.api.nvim_create_user_command("ToggleCMDHeight", function() toggle_o("cmdheight", 1, 0) end, {})
        vim.api.nvim_create_user_command("ToggleAutoWrap", function() toggle_local_opt("formatoptions", "t") end, {})
        vim.api.nvim_create_user_command("ToggleCommentAutoWrap", function() toggle_local_opt("formatoptions", "c") end, {})
        vim.api.nvim_create_user_command("ToggleParagraphAutoFormat", function() toggle_local_opt("formatoptions", "a") end, {})
        vim.api.nvim_create_user_command('HighlightGroups', function() vim.cmd.so('$VIMRUNTIME/syntax/hitest.vim') end, {})
      '';
}
