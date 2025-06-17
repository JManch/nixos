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
        vim.api.nvim_create_autocmd("ColorScheme", {
          group = vim.api.nvim_create_augroup("DashboardHighlights", { clear = true }),
          pattern = "*",
          desc = "Link dashboard hightlight groups",
          callback = function()
            vim.api.nvim_set_hl(0, "DashboardHeader", { link = "Identifier" })
            vim.api.nvim_set_hl(0, "DashboardFooter", { link = "CmpItemMenu" })
          end,
        })
      '';
}
