-- TODO:
-- Fix git update opening file
-- Fix searchcount update when clearing search
local setup_colors = function()
  return require("ayu.colors")
end
local conditions = require("heirline.conditions")
local utils = require("heirline.utils")

require("heirline").load_colors(setup_colors)

vim.api.nvim_create_augroup("Heirline", { clear = true })
vim.api.nvim_create_autocmd("ColorScheme", {
  group = "Heirline",
  callback = function()
    utils.on_colorscheme(setup_colors)
  end,
})

local align = { provider = "%=" }
local space = { provider = " " }

local vi_mode = {
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
      ["t"] = "TERMINAL",
    },
  },

  provider = function(self)
    return " " .. self.mode_names[vim.fn.mode(1)] .. " "
  end,

  hl = function(self)
    return self:mode_highlight()
  end,

  update = {
    "ModeChanged",
    pattern = "*:*",
    callback = vim.schedule_wrap(function()
      vim.cmd("redrawstatus")
    end),
  },
}

local git = {
  condition = conditions.is_git_repo,
  init = function(self)
    self.status_dict = vim.b.gitsigns_status_dict
    self.has_changes = self.status_dict.added ~= 0 or self.status_dict.removed ~= 0 or self.status_dict.changed ~= 0
  end,
  hl = { fg = "entity" },
  {
    provider = function(self)
      return " " .. self.status_dict.head
    end,
    hl = function(self)
      return { fg = self:mode_highlight().bg }
    end,
  },
  {
    provider = function(self)
      local count = self.status_dict.added or 0
      return count > 1 and (" +" .. count)
    end,
    hl = { fg = "vcs_added" },
  },
  {
    provider = function(self)
      local count = self.status_dict.removed or 0
      return count > 0 and (" -" .. count)
    end,
    hl = { fg = "vcs_removed" },
  },
  {
    provider = function(self)
      local count = self.status_dict.changed or 0
      return count > 0 and (" ~" .. count)
    end,
    hl = { fg = "vcs_modified" },
  },
}

local file_name_block = {
  init = function(self)
    self.filename = vim.api.nvim_buf_get_name(0)
  end,
  provider = function()
    return "%="
  end,
  {
    init = function(self)
      local filename = self.filename
      local extension = vim.fn.fnamemodify(filename, ":e")
      self.icon, self.icon_color =
      require("nvim-web-devicons").get_icon_color(filename, extension, { default = true })
    end,
    provider = function(self)
      return self.icon and (self.icon .. " ")
    end,
    hl = function(self)
      return { fg = self.icon_color }
    end,
  },
  {
    init = function(self)
      self.lfilename = vim.fn.fnamemodify(self.filename, ":.")
      if self.lfilename == "" then
        self.lfilename = "[No Name]"
      end
    end,
    flexible = 2,
    {
      provider = function(self)
        return self.lfilename
      end,
    },
    {
      provider = function(self)
        return vim.fn.pathshorten(self.lfilename)
      end,
    },
  },
  {
    condition = function()
      return vim.bo.modified
    end,
    provider = " [+]",
  },
  {
    condition = function()
      return not vim.bo.modifiable or vim.bo.readonly
    end,
    provider = " [-]",
  },
}

local search_count = {
  condition = function()
    return vim.v.hlsearch ~= 0
  end,

  hl = function(self)
    return { fg = self:mode_highlight().bg }
  end,

  provider = function()
    local ok, result = pcall(vim.fn.searchcount, { maxcount = 999, timeout = 500 })
    if not ok or next(result) == nil then
      return ""
    end
    local denominator = math.min(result.total, result.maxcount)
    return string.format("[%d/%d]", result.current, denominator)
  end,
}

local position = {
  provider = " %P ",
  hl = function(self)
    return self:mode_highlight()
  end,
}

local statusline = {
  vi_mode,
  space,
  git,
  file_name_block,
  align,
  search_count,
  space,
  position,
  hl = { fg = "fg", bg = "panel_border" },
  static = {
    mode_highlights_map = {
      n = { fg = "bg", bg = "entity", bold = true },
      i = { fg = "bg", bg = "string", bold = true },
      v = { fg = "bg", bg = "accent", bold = true },
      ["\22"] = { fg = "bg", bg = "accents", bold = true },
      c = { fg = "bg", bg = "constant", bold = true },
      s = { fg = "bg", bg = "accent", bold = true },
      ["\19"] = { fg = "bg", bg = "accent", bold = true },
      r = { fg = "bg", bg = "markup", bold = true },
      ["!"] = { fg = "bg", bg = "string", bold = true },
      t = { fg = "bg", bg = "string", bold = true },
    },

    mode_highlight = function(self)
      local mode = conditions.is_active() and vim.fn.mode():lower() or "n"
      return self.mode_highlights_map[mode]
    end,
  },
}

require("heirline").setup({
  statusline = statusline,
})
