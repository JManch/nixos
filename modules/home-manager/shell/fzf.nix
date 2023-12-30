{ lib
, config
, ...
}:
lib.mkIf config.modules.shell.enable {
  programs.fzf = {
    enable = true;
    colors = {
      # TODO: Properly setup this colorscheme
      bg = "#${config.colorscheme.colors.base00}";
      fg = "#${config.colorscheme.colors.base05}";
      hl = "${config.colorscheme.colors.base0B}";
    };
  };
}
