{
  ns,
  lib,
  pkgs,
  config,
  inputs,
  desktopEnabled,
  ...
}:
let
  inherit (lib) mkIf getExe';
  inherit (config.${ns}) colorScheme;
  inherit (config.${ns}.desktop.services) darkman;
  inherit (config.${ns}.desktop.style) cursor customTheme;
  inherit (inputs.nix-colors.lib-contrib { inherit pkgs; }) gtkThemeFromScheme;
  cfg = config.${ns}.desktop;
  darkTheme = gtkThemeFromScheme { scheme = colorScheme.dark; };
  lightTheme = gtkThemeFromScheme { scheme = colorScheme.light; };
in
mkIf desktopEnabled {
  home.packages = mkIf customTheme [
    darkTheme
    lightTheme
  ];

  gtk = {
    enable = true;

    # If darkman is enabled the theme will be applied using gsettings in the
    # switch script
    theme = mkIf (cfg.style.customTheme && !darkman.enable) {
      name = colorScheme.dark.slug;
      package = darkTheme;
    };

    iconTheme = mkIf cfg.style.customTheme {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
  };

  darkman.switchScripts.gtk =
    let
      schemas = pkgs.gsettings-desktop-schemas;
      gsettings = getExe' pkgs.glib "gsettings";
    in
    theme: # bash
    ''
      export XDG_DATA_DIRS=${schemas}/share/gsettings-schemas/${schemas.name}
      ${gsettings} set org.gnome.desktop.interface gtk-theme ${colorScheme.${theme}.slug}
      ${gsettings} set org.gnome.desktop.interface color-scheme prefer-${theme}
    '';

  # Also sets gtk.cursorTheme
  home.pointerCursor = mkIf cursor.enable {
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
