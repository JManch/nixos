-- TODO:
-- Fix searchcount update when clearing search
local setup_colors = function() return require("ayu.colors") end
local conditions = require("heirline.conditions")
local utils = require("heirline.utils")

require("heirline").load_colors(setup_colors)

vim.api.nvim_create_autocmd("ColorScheme", {
  group = vim.api.nvim_create_augroup("Heirline", {}),
  callback = function() utils.on_colorscheme(setup_colors) end
})

local left_char_count = {}

local count_provider = function(name, provider)
  return function(self)
    local result
    if type(provider) == "function" then
      result = provider(self)
    else
      result = provider
    end

    if not result then
      left_char_count[name] = 0
    else
      left_char_count[name] = utils.count_chars(result)
    end
    return result
  end
end

local count_condition = function(names, condition)
  return function(self)
    local result = condition(self)
    if not result then
      if type(names) == "string" then
        left_char_count[names] = 0
      else
        for _, v in pairs(names) do left_char_count[v] = 0 end
      end
    end
    return result
  end
end

local mode = {
  static = {
    mode_names = {
      ["n"] = "NORMAL",
      ["no"] = "O-PENDING",
      ["nov"] = "O-PENDING",
      ["noV"] = "O-PENDING",
      ["no\22"] = "O-PENDING",
      ["niI"] = "NORMAL",
      ["niR"] = "NORMAL",
      ["niV"] = "NORMAL",
      ["nt"] = "NORMAL",
      ["ntT"] = "NORMAL",
      ["v"] = "VISUAL",
      ["vs"] = "VISUAL",
      ["V"] = "V-LINE",
      ["Vs"] = "V-LINE",
      ["\22"] = "V-BLOCK",
      ["\22s"] = "V-BLOCK",
      ["s"] = "SELECT",
      ["S"] = "S-LINE",
      ["\19"] = "S-BLOCK",
      ["i"] = "INSERT",
      ["ic"] = "INSERT",
      ["ix"] = "INSERT",
      ["R"] = "REPLACE",
      ["Rc"] = "REPLACE",
      ["Rx"] = "REPLACE",
      ["Rv"] = "V-REPLACE",
      ["Rvc"] = "V-REPLACE",
      ["Rvx"] = "V-REPLACE",
      ["c"] = "COMMAND",
      ["cr"] = "COMMAND",
      ["cv"] = "EX",
      ["cvr"] = "EX",
      ["r"] = "REPLACE",
      ["rm"] = "MORE",
      ["r?"] = "CONFIRM",
      ["!"] = "SHELL",
      ["t"] = "TERMINAL"
    }
  },

  provider = count_provider("mode", function(self)
    return " " .. self.mode_names[vim.fn.mode(1)] .. " "
  end),

  hl = function(self) return self:mode_highlight() end

  -- Causes mode to get stuck on "TERMINAL" after using fzf-lua
  -- update = {
  --   "ModeChanged",
  --   pattern = "*:*",
  --   callback = vim.schedule_wrap(function() vim.cmd("redrawstatus") end)
  -- }
}

local git = {
  condition = count_condition({
    "git_branch", "git_added", "git_removed", "git_modified"
  }, conditions.is_git_repo),
  init = function(self) self.status_dict = vim.b.gitsigns_status_dict end,
  hl = {fg = "entity"},
  {
    provider = count_provider("git_branch", function(self)
      return "  " .. self.status_dict.head
    end),
    hl = function(self) return {fg = self:mode_highlight().bg} end
  },
  {
    provider = count_provider("git_added", function(self)
      local count = self.status_dict.added or 0
      return count > 0 and (" +" .. count)
    end),
    hl = {fg = "vcs_added"}
  },
  {
    provider = count_provider("git_removed", function(self)
      local count = self.status_dict.removed or 0
      return count > 0 and (" -" .. count)
    end),
    hl = {fg = "vcs_removed"}
  },
  {
    provider = count_provider("git_modified", function(self)
      local count = self.status_dict.changed or 0
      return count > 0 and (" ~" .. count)
    end),
    hl = {fg = "vcs_modified"}
  }
}

local filename_block = {
  -- Calculate stuff for children here so we can predict padding in this eval.
  -- Otherwise one eval cycling has incorrect padding and it causes stuff to
  -- jump around. 
  init = function(self)
    local filename = vim.api.nvim_buf_get_name(0)

    local extension = vim.fn.fnamemodify(filename, ":e")
    self.icon, self.icon_color = require("nvim-web-devicons").get_icon_color(filename, extension, {default = true})
    self.icon_str = self.icon and (self.icon .. " ")

    self.lfilename = vim.fn.fnamemodify(filename, ":.")
    if self.lfilename == "" then self.lfilename = "[No Name]" end

    if vim.bo.modified then
      self.tag_str = " [+]"
    elseif not vim.bo.modifiable or vim.bo.readonly then
      self.tag_str = " [-]"
    else
      self.tag_str = ""
    end

    self.filename_chars = utils.count_chars(self.icon_str .. self.lfilename .. self.tag_str)
  end,
  {
    provider = function(self)
      local left_chars = 0
      for _, v in pairs(left_char_count) do left_chars = left_chars + v end
      local right_chars = vim.o.columns - (left_chars + self.filename_chars)

      -- Because we left align the filename by default right_chars will always
      -- be >= left_chars
      return " " .. string.rep(' ', math.floor((right_chars - left_chars) / 2))
    end
  },
  {
    provider = function(self) return self.icon_str end,
    hl = function(self) return {fg = self.icon_color} end
  },
  {provider = function(self) return self.lfilename .. self.tag_str end}
}

local search_count = {
  condition = function() return vim.v.hlsearch ~= 0 end,
  hl = function(self) return {fg = self:mode_highlight().bg} end,
  provider = function()
    local ok, result =
        pcall(vim.fn.searchcount, {maxcount = 999, timeout = 500})
    if not ok or next(result) == nil then return "" end
    local denominator = math.min(result.total, result.maxcount)
    return string.format(" [%d/%d]", result.current, denominator)
  end
}

local diagnostics = {
  condition = conditions.has_diagnostics,
  static = {
    error_icon = vim.diagnostic.config()['signs']['text']['vim.diagnostic.severity.ERROR'],
    warn_icon = vim.diagnostic.config()['signs']['text']['vim.diagnostic.severity.WARN'],
    info_icon = vim.diagnostic.config()['signs']['text']['vim.diagnostic.severity.INFO'],
    hint_icon = vim.diagnostic.config()['signs']['text']['vim.diagnostic.severity.HINT'],
  },
  init = function(self)
    self.errors = #vim.diagnostic.get(0, { severity = vim.diagnostic.severity.ERROR })
    self.warnings = #vim.diagnostic.get(0, { severity = vim.diagnostic.severity.WARN })
    self.hints = #vim.diagnostic.get(0, { severity = vim.diagnostic.severity.HINT })
    self.info = #vim.diagnostic.get(0, { severity = vim.diagnostic.severity.INFO })
  end,
  update = { "DiagnosticChanged", "BufEnter" },
  {
    provider = function(self)
      return self.errors > 0 and (" " .. self.error_icon .. self.errors)
    end,
    hl = { fg = "error" },
  },
  {
    provider = function(self)
      return self.warnings > 0 and (" " .. self.warn_icon .. self.warnings)
    end,
    hl = { fg = "keyword" },
  },
  {
    provider = function(self)
      return self.info > 0 and (" " .. self.info_icon .. self.info)
    end,
    hl = { fg = "tag" },
  },
  {
    provider = function(self)
      return self.hints > 0 and (" " .. self.hint_icon .. self.hints)
    end,
    hl = { fg = "regexp" },
  },
}

local tabs = {
  init = function(self)
    self.tab_count = vim.fn.tabpagenr('$')
  end,
  provider = function(self)
    return self.tab_count ~= 1 and (" " .. vim.fn.tabpagenr() .. "/" .. self.tab_count)
  end,
  hl = function(self) return {fg = self:mode_highlight().bg} end
}

local position = {
  { provider = " "},
  {
    provider = " %P ",
    hl = function(self) return self:mode_highlight() end
  }
}

local statusline = {
  hl = {fg = "fg", bg = "panel_border"},
  static = {
    mode_highlights_map = {
      n = {fg = "bg", bg = "entity", bold = true},
      i = {fg = "bg", bg = "string", bold = true},
      v = {fg = "bg", bg = "accent", bold = true},
      ["\22"] = {fg = "bg", bg = "accent", bold = true},
      c = {fg = "bg", bg = "constant", bold = true},
      s = {fg = "bg", bg = "accent", bold = true},
      ["\19"] = {fg = "bg", bg = "accent", bold = true},
      r = {fg = "bg", bg = "markup", bold = true},
      ["!"] = {fg = "bg", bg = "string", bold = true},
      t = {fg = "bg", bg = "string", bold = true}
    },

    mode_highlight = function(self)
      local mode = conditions.is_active() and vim.fn.mode():lower() or "n"
      return self.mode_highlights_map[mode]
    end
  },
  mode,
  git,
  filename_block,
  {provider = "%="},
  search_count,
  diagnostics,
  tabs,
  position
}

require("heirline").setup({statusline = statusline})
