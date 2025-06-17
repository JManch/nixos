{ lib, ... }:
{
  vim.dashboard.dashboard-nvim = {
    enable = true;
    setupOpts = {
      theme = "doom";
      disable_move = true;
      config = {
        vertical_center = true;
        header = [
          "       __           __               "
          "      / /___  _____/ /_  __  ______ _"
          " __  / / __ \\/ ___/ __ \\/ / / / __ `/"
          "/ /_/ / /_/ (__  ) / / / /_/ / /_/ / "
          "\\____/\\____/____/_/ /_/\\__,_/\\__,_/  "
          "                                     "
          "                                     "
        ];
        center =
          let
            mkButton = icon: key: desc: action: {
              inherit
                icon
                key
                desc
                action
                ;
              # keymap = key;
              icon_hl = "CmpItemMenu";
              desc_hl = "CmpItemMenu";
              key_hl = "CmpItemMenu";
              key_format = "   %s";
            };
          in
          [
            (mkButton "  " "e" "New file" (
              lib.generators.mkLuaInline ''
                function()
                  vim.cmd('enew')
                  vim.cmd('startinsert')
                end
              ''
            ))
            (mkButton "  " "f" "Find file" "FzfLua files")
            (mkButton "  " "d" "Browse files" "Oil --float --preview")
            (mkButton "  " "w" "Load workspace" "WorkspacesOpen")
            (mkButton "  " "n" "Open notes" "Notes<BAR> startinsert")
            (mkButton "  " "q" "Quit" "qa")
          ];

        footer =
          lib.generators.mkLuaInline
            # lua
            ''
              function()
                return { "", string.match(vim.api.nvim_exec2('version', { output = true }).output, 'NVIM (.-)\n'), "", "", "", "" }
              end
            '';
      };
    };
  };

  vim.luaConfigRC.dashboardHighlights =
    lib.nvim.dag.entryBefore [ "theme" ]
      # lua
      ''
        local dashboard_utils = {
          group = vim.api.nvim_create_augroup("DashboardCustom", { clear = true }),
          cursor_blend = function(value)
            local hl = vim.api.nvim_get_hl(0, { name = "Cursor", create = true })
            hl.blend = value
            vim.api.nvim_set_hl(0, "Cursor", hl)
            vim.cmd("set guicursor+=a:Cursor/lCursor")
          end,
        }

        vim.api.nvim_create_autocmd("ColorScheme", {
          group = dashboard_utils.group,
          pattern = "*",
          desc = "Link dashboard highlight groups",
          callback = function()
            vim.api.nvim_set_hl(0, "DashboardHeader", { link = "Identifier" })
            vim.api.nvim_set_hl(0, "DashboardFooter", { link = "CmpItemMenu" })
          end,
        })

        -- For hiding cursor when dashboard is opened on launch or later with
        -- :Dashboard
        vim.api.nvim_create_autocmd('User', {
          group = dashboard_utils.group,
          pattern = 'DashboardLoaded',
          callback = function()
            dashboard_utils.cursor_blend(100)
            vim.api.nvim_create_autocmd({'BufLeave', 'TermOpen'}, {
              callback = function()
                dashboard_utils.cursor_blend(0)
                return true
              end,
            })
          end
        })

        -- For hiding cursor the dashboard is re-focused e.g. by closing
        -- fzf-lua terminal
        vim.api.nvim_create_autocmd('BufEnter', {
          group = dashboard_utils.group,
          callback = function()
            if vim.bo.filetype ~= 'dashboard' then return end
            dashboard_utils.cursor_blend(100)
            vim.api.nvim_create_autocmd({'BufLeave', 'TermOpen'}, {
              callback = function()
                dashboard_utils.cursor_blend(0)
                return true
              end,
            })
          end,
        })
      '';
}
