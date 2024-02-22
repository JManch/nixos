{ lib
, pkgs
, config
, osConfig
, ...
}:
let
  desktopCfg = config.modules.desktop;
  colors = config.colorscheme.palette;
  cursorName = "Bibata-Modern-Classic";
in
lib.mkIf osConfig.usrEnv.desktop.enable
{
  xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gtk ];

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
  };

  # Also sets gtk.cursorTheme
  home.pointerCursor = {
    gtk.enable = true;
    name = cursorName;
    package = pkgs.bibata-cursors;
    size = desktopCfg.style.cursorSize;
  };

  desktop.hyprland.settings =
    let
      hyprctl = lib.getExe' config.wayland.windowManager.hyprland.package "hyprctl";
    in
    {
      env = [
        "XCURSOR_THEME,${cursorName}"
        "XCURSOR_SIZE,${toString desktopCfg.style.cursorSize}"
      ];

      exec-once = [
        "${hyprctl} setcursor ${cursorName} ${toString desktopCfg.style.cursorSize}"
      ];
    };
}
