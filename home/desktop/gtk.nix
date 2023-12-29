{ pkgs, config, ... }: {
  gtk = {
    enable = true;
    theme = {
      name = "Plata-Noir-Compact";
      package = pkgs.plata-theme;
    };
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
    cursorTheme = {
      name = "Bibata-Modern-Classic";
      package = pkgs.bibata-cursors;
      size = config.desktop.cursorSize;
    };
  };

  wayland.windowManager.hyprland.settings.env = [
    "XCURSOR_THEME,Bibata-Modern-Classic"
    "XCURSOR_SIZE,${builtins.toString config.desktop.cursorSize}"
  ];
}
