{ pkgs
, config
, osConfig
, lib
, ...
}:
lib.mkIf osConfig.usrEnv.desktop.enable {
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
      size = config.modules.desktop.cursorSize;
    };
  };

  wayland.windowManager.hyprland.settings = lib.mkIf (osConfig.usrEnv.desktop.compositor == "hyprland") {
    env = [
      "XCURSOR_THEME,${config.gtk.cursorTheme.name}"
      "XCURSOR_SIZE,${builtins.toString config.modules.desktop.cursorSize}"
    ];
    exec-once = [
      "hyprctl setcursor ${config.gtk.cursorTheme.name} ${builtins.toString config.modules.desktop.cursorSize}"
    ];
  };
}
