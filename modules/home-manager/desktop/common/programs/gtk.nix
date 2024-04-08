{ lib
, pkgs
, config
, osConfig
, ...
}:
let
  inherit (config.modules.desktop.style) cursor;
  colors = config.colorscheme.palette;
in
lib.mkIf osConfig.usrEnv.desktop.enable
{
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

  xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gtk ];

  # Also sets gtk.cursorTheme
  home.pointerCursor = {
    gtk.enable = true;
    name = cursor.name;
    package = cursor.package;
    size = cursor.size;
  };

  desktop.hyprland.settings = {
    env = [
      "XCURSOR_THEME,${cursor.name}"
      "XCURSOR_SIZE,${toString cursor.size}"
    ];
  };
}
