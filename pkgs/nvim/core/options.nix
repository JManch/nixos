{ lib, ... }:
{
  config.vim = {
    options = {
      winborder = "rounded";
      timeoutlen = 600;
      mouse = "a";
      exrc = true;
      ignorecase = true;
      smartcase = true;
      spelllang = "en_gb";
      relativenumber = true;
      number = true;
      wrap = false;
      linebreak = true;
      showbreak = ">";
      scrolloff = 8;
      signcolumn = "yes";
      showmode = false;
      splitright = true;
      splitbelow = true;
      showtabline = 0;
      list = true;
      laststatus = 3;
      expandtab = true;
      shiftwidth = 2;
      tabstop = 2;
      foldenable = false;
      breakindent = true;
      ruler = false;
      title = true;
    };

    globals = {
      mapleader = " ";
      maplocalleader = ",";
      loaded_node_provider = 0;
      loaded_perl_provider = 0;
      loaded_ruby_provider = 0;
      loaded_gem_provider = 0;
    };

    luaConfigRC.extraOptions =
      lib.nvim.dag.entryBetween [ "optionsScript" ] [ "theme" ]
        # lua
        ''
          local opt = vim.opt
          opt.jumpoptions = { 'stack', 'view' }
          opt.diffopt:append('linematch:60')
          opt.fillchars = { eob = ' ' }
          opt.completeopt = { 'menu', 'menuone', 'noselect', 'preview' }
          opt.listchars:append({
            trail = '·',
            tab = '  ',
          })

          -- TODO: Figure out if this is works. Ideally would fetch the dictionary in a Nix derivation
          -- local dict_path = vim.fs.normalize(vim.fn.stdpath('data') .. '/en.dict')
          -- if vim.loop.fs_stat(dict_path) ~= nil then
          --   opt.dictionary:append(dict_path)
          -- end
        '';
  };
}
