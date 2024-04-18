{ lib
, pkgs
, config
, inputs
, osConfig
, ...
}:
let
  inherit (lib) mkIf getExe';
  inherit (config.modules) colorScheme;
  inherit (config.modules.desktop.style) cursor;
  inherit (config.modules.desktop.services) darkman;
  inherit (inputs.nix-colors.lib-contrib { inherit pkgs; }) gtkThemeFromScheme;
  darkTheme = gtkThemeFromScheme { scheme = colorScheme.dark; };
  lightTheme = gtkThemeFromScheme { scheme = colorScheme.light; };
in
mkIf osConfig.usrEnv.desktop.enable
{
  home.packages = [
    darkTheme
    lightTheme
  ];

  gtk = {
    enable = true;

    # If darkman is enabled the theme will be applied using gsettings in the
    # switch script
    theme = mkIf (!darkman.enable) {
      name = darkTheme.slug;
      package = darkTheme;
    };

    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
  };

  darkman.switchScripts.gtk =
    let
      schemas = pkgs.gsettings-desktop-schemas;
      gsettings = getExe' pkgs.glib "gsettings";
    in
    theme: /*bash*/ ''
      export XDG_DATA_DIRS=${schemas}/share/gsettings-schemas/${schemas.name}
      ${gsettings} set org.gnome.desktop.interface gtk-theme ${colorScheme.${theme}.slug}
      ${gsettings} set org.gnome.desktop.interface color-scheme prefer-${theme}
    '';

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
