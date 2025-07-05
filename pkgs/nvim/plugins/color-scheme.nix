{
  lib,
  pkgs,
  sources,
  ...
}:
{
  vim.startPlugins = [
    (pkgs.vimPlugins.neovim-ayu.overrideAttrs {
      version = "0-unstable-${sources.neovim-ayu.revision}";
      src = sources.neovim-ayu;
      patches = [ ../../../patches/neovim-ayu-colors.patch ];
    })

    (pkgs.vimUtils.buildVimPlugin {
      pname = "sunset.nvim";
      version = "0-unstable-${sources."sunset.nvim".revision}";
      src = sources."sunset.nvim";
      meta.homepage = "https://github.com/JManch/sunset.nvim";
    })
  ];

  vim.luaConfigRC.theme =
    lib.nvim.dag.entryBefore [ "pluginConfigs" "lazyConfigs" ]
      # lua
      ''
        vim.api.nvim_create_autocmd('ColorScheme', {
          group = vim.api.nvim_create_augroup('SetHighlights', {}),
          pattern = "*",
          callback = function()
            vim.api.nvim_set_hl(0, 'MatchParen', { link = 'Constant' })

            -- Missing highlight groups from ayu
            vim.api.nvim_set_hl(0, 'Bold', { bold = true })
            vim.api.nvim_set_hl(0, 'Italic', { italic = true })
            vim.api.nvim_set_hl(0, '@text.strong', { link = 'Bold' })
            vim.api.nvim_set_hl(0, '@text.emphasis', { link = 'Italic' })
            vim.api.nvim_set_hl(0, '@text.literal.help', { link = 'help' })
          end,
        })

        local colors = require('ayu.colors')
        colors.generate(true)
        require('ayu').setup({
          overrides = function()
            return {
              Pmenu = { bg = colors.panel_bg },
              PmenuSel = { fg = "None", reverse = false },
              Comment = { italic = false },
            }
          end
        })

        local sunset_opts = {
          day_callback = function()
            vim.cmd.colorscheme("ayu-light")
          end,
          night_callback = function()
            vim.cmd.colorscheme("ayu-mirage")
          end,
          update_interval = 10000,
          latitude = 50.85,
          longitute = -0.14,
          sunrise_offset = 1800,
          sunset_offset = -1800,
        }

        if os.getenv("NIX_NEOVIM_DARKMAN") == "1" and (os.getenv("DISPLAY") ~= nil or os.getenv("wayland_display") ~= nil) then
          sunset_opts.custom_switch = function(tbl)
            if not tbl.init then
              if tbl.is_day then
                tbl.trigger_day()
              else
                tbl.trigger_night()
              end
              return
            end

            local result = vim.system({ "darkman", "get" }, { text = true }):wait()
            if vim.trim(result.stdout) == "light" then
              tbl.trigger_day()
            else
              tbl.trigger_night()
            end
          end
        end

        require("sunset").setup(sunset_opts)
      '';

  vim.keymaps = [
    (lib.nvim.binds.mkKeymap "n" "<LEADER>C" "<CMD>SunsetToggle<CR>" {
      desc = "Toggle sunset theme";
    })
  ];
}
