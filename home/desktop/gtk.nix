{
  pkgs,
  config,
  ...
}: {
  gtk = {
    enable = true;
    theme = {
      name = "Plata-Noir-Compact";
      package = pkgs.plata-theme.override {
        selectionColor = "#${config.colorscheme.colors.base01}";
        accentColor = "#${config.colorscheme.colors.base02}";
        suggestionColor = "#${config.colorscheme.colors.base0D}";
        destructionColor = "#${config.colorscheme.colors.base08}";
      };
    };
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
    cursorTheme = {
      name = "Bibata-Modern-Classic";
      package = pkgs.bibata-cursors;
      size = 24;
    };
  };
}
