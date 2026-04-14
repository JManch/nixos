local actions = require("fzf-lua").actions

local copy_hash = function(selected, opts)
  local commit_hash = match_commit_hash(selected[1], opts)
  vim.fn.setreg([[+]], commit_hash)
  vim.fn.setreg([["]], commit_hash)
  vim.fn.setreg([[0]], commit_hash)
end

vim.env.FZF_DEFAULT_OPTS = nil

require("fzf-lua").setup { "default",
  fzf_colors = true,
  fzf_bin = "@fzf_bin@",

  fzf_opts = {
    ["--layout"] = "reverse",
    ["--cycle"]  = true,
    ["--gutter"] = " ",
    ["--marker"] = "+",
  },

  actions = {
    files = {
      ["enter"]  = actions.file_edit_or_qf,
      ["ctrl-x"] = actions.file_split,
      ["ctrl-v"] = actions.file_vsplit,
      ["ctrl-t"] = actions.file_tabedit,
      ["ctrl-q"]  = actions.file_sel_to_qf,
    },
  },

  buffers = {
    previewer = false,
    winopts = {
      height = 0.23,
      width  = 0.80,
      row    = 0.50,
    },
    actions = {
      ["ctrl-x"] = { fn = actions.buf_del, reload = true },
    },
    fzf_opts = {
      ["--header-lines"] = false, -- hide the <ctrl-x> to close line
    },
  },

  files = {
    cmd        = "fd",
    cwd_prompt = false,
    fd_opts    = "[[--type f --type l --exclude .git]]",
    hidden     = false,
    -- Unfortunately can't use fzfs dynamic --preview-window options
    previewer  = function()
      return vim.o.columns > 120 and "builtin" or false
    end,
  },

  git = {
    commits = { actions = {  ['ctrl-y'] = copy_hash } },
    bcommits = { actions = {  ['ctrl-y'] = copy_hash } },
    blame = {
      winopts = {
        preview = {
          layout = "vertical",
          vertical = "down:65%",
        },
      },
    },
  },

  keymap = {
    builtin = {
      true,
      ["<C-u>"] = "preview-page-up",
      ["<C-d>"] = "preview-page-down",
      ["<C-p>"] = "preview-up",
      ["<C-n>"] = "preview-down",
    },
    fzf = {
      true,
      ["ctrl-u"] = "preview-page-up",
      ["ctrl-d"] = "preview-page-down",
      ["ctrl-p"] = "preview-up",
      ["ctrl-n"] = "preview-down",
    },
  },

  winopts = {
    backdrop = 100,
    border   = "rounded",
    height   = 0.90,
    width    = 0.80,
    preview  = {
      layout       = "flex",
      flip_columns = 120,
      hidden       = false,
      horizontal   = "right:65%",
      vertical     = "down:65%",
      scrollbar    = false,
      winopts      = { number = false },
    },
  },
}

require("fzf-lua").register_ui_select(function(ui_opts)
  ui_opts.winopts = {
    height = 15,
    width = 80,
    row = 0.45,
    col = 0.5,
  }
  return ui_opts
end)
