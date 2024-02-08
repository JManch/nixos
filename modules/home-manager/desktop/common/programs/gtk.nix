{ lib
, pkgs
, config
, osConfig
, ...
}:
let
  desktopCfg = config.modules.desktop;
  colors = config.colorscheme.palette;
in
lib.mkIf osConfig.usrEnv.desktop.enable {
  # TODO: Consider settings home.pointerCursor
  gtk = {
    enable = true;
    theme = {
      # TODO: Consider generating the GTK theme from nix-colors
      name = "Plata-Noir-Compact";
      package = pkgs.plata-theme.override {
        selectionColor = "#${colors.base01}";
        accentColor = "#${colors.base02}";
        suggestionColor = "#${colors.base0D}";
        destructionColor = "#${colors.base08}";
      };
    };
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
    cursorTheme = {
      name = "Bibata-Modern-Classic";
      package = pkgs.bibata-cursors;
      size = desktopCfg.style.cursorSize;
    };
  };

  xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gtk ];

  desktop.hyprland.settings = lib.mkIf (desktopCfg.windowManager == "hyprland") {
    env = [
      "XCURSOR_THEME,${config.gtk.cursorTheme.name}"
      "XCURSOR_SIZE,${builtins.toString desktopCfg.style.cursorSize}"
    ];
    exec-once = [
      "hyprctl setcursor ${config.gtk.cursorTheme.name} ${builtins.toString desktopCfg.style.cursorSize}"
    ];
  };

}
