{
  lib,
  pkgs,
  config,
  inputs,
  desktopEnabled,
  ...
}:
let
  inherit (lib) mkIf getExe';
  inherit (config.modules) colorScheme;
  inherit (config.modules.desktop.services) darkman;
  inherit (config.modules.desktop.style) cursor;
  inherit (inputs.nix-colors.lib-contrib { inherit pkgs; }) gtkThemeFromScheme;
  cfg = config.modules.desktop;
  darkTheme = gtkThemeFromScheme { scheme = colorScheme.dark; };
  lightTheme = gtkThemeFromScheme { scheme = colorScheme.light; };
in
mkIf desktopEnabled {
  home.packages = mkIf (cfg.style.customTheme) [
    darkTheme
    lightTheme
  ];

  gtk = {
    enable = true;

    # If darkman is enabled the theme will be applied using gsettings in the
    # switch script
    theme = mkIf (cfg.style.customTheme && !darkman.enable) {
      name = darkTheme.slug;
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
