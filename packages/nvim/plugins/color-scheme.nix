{
  lib,
  pkgs,
  sources,
  ...
}:
{
  vim.startPlugins = [
    (pkgs.vimPlugins.neovim-ayu.overrideAttrs {
      # Pinning as I do not like how the recently added native blink.cmp highlights look
      version = "0-unstable-2025-10-21";
      src = pkgs.fetchFromGitHub {
        owner = "Shatur";
        repo = "neovim-ayu";
        rev = "38caa8b5b969010b1dcae8ab1a569d7669a643d5";
        hash = "sha256-2Gt//JJZEMwsI/R9OR1orLYg4Eur6gvDWhAqQ498R6E=";
      };
      patches = [
        ../../../patches/neovim-ayu-colors.patch
        # as haskell-tools.nvim uses code lenses instead of inlay hints
        # https://github.com/mrcjkb/haskell-tools.nvim/issues/364
        ../../../patches/neovim-ayu-code-lens.patch
      ];
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

        local get_coord = function(coord)
          local file = io.open("/etc/coordinates/" .. coord, "rb")
          if not file then return nil end
          local content = file:read("*a")
          file:close()
          if not content then return nil end
          return tonumber(content)
        end

        latitude = get_coord("latitude") or 50.8
        longitude = get_coord("longitude") or -0.1

        local sunset_opts = {
          day_callback = function()
            vim.cmd.colorscheme("ayu-light")
          end,
          night_callback = function()
            vim.cmd.colorscheme("ayu-mirage")
          end,
          update_interval = 10000,
          latitude = latitude,
          longitude = longitude,
          sunrise_offset = 1800,
          sunset_offset = -1800,
        }

        if vim.env.NIX_NEOVIM_DARKMAN == "1" or vim.env.DARKMAN_THEME ~= nil then
          sunset_opts.custom_switch = function(tbl)
            if not tbl.init then return end

            local theme = vim.env.DARKMAN_THEME
            if (vim.env.NIX_NEOVIM_DARKMAN == "1" and (vim.env.DISPLAY ~= nil or vim.env.WAYLAND_DISPLAY ~= nil)) then
              local result = vim.system({ "darkman", "get" }, { text = true }):wait()
              theme = vim.trim(result.stdout)
            end

            if theme == "light" then
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
