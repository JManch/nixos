{
  lib,
  cfg,
  pkgs,
  config,
  osConfig,
}:
let
  inherit (lib)
    ns
    mkIf
    getExe'
    mkEnableOption
    ;
  inherit (config.${ns}) desktop;
  inherit (desktop.style) cursor;
in
{
  enableOpt = false;

  opts.customTheme = mkEnableOption "custom GTK icon theme and adw-gtk3 theme" // {
    default = osConfig.${ns}.system.desktop.desktopEnvironment == null;
  };

  gtk = {
    enable = true; # always need this enabled for cursor configuration

    theme = mkIf cfg.customTheme {
      name = "adw-gtk3-dark";
      # Not generating a custom gtk.css file from our base16 colorscheme like
      # stylix does because using gtk.css does not allow hot-reloading when
      # switching between light and dark theme variants.

      # Used to generate a gtk theme using nix colors but the theme made a bunch
      # of apps look terrible. Sticking to adwaita seems best.
      package = pkgs.adw-gtk3;
    };

    # Do not theme gtk4 because it generates a gtk-4.0/gtk.css file which
    # breaks light/dark theme switches (gtk.css themes cannot be hot-reloaded).
    # Just gonna give up on GTK 4 theming.
    gtk4.theme = null;

    iconTheme = mkIf cfg.customTheme {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
  };

  ns.desktop.darkman.switchScripts.gtk =
    let
      schemas = pkgs.gsettings-desktop-schemas;
      gsettings = getExe' pkgs.glib "gsettings";
      gtkTheme = {
        dark = if cfg.customTheme then "adw-gtk3-dark" else "Adwaita-dark";
        light = if cfg.customTheme then "adw-gtk3" else "Adwaita";
      };
    in
    theme: # bash
    ''
      export XDG_DATA_DIRS=${schemas}/share/gsettings-schemas/${schemas.name}
      ${gsettings} set org.gnome.desktop.interface gtk-theme ${gtkTheme.${theme}}
      ${gsettings} set org.gnome.desktop.interface color-scheme prefer-${theme}
    '';

  # Also sets gtk.cursorTheme
  home.pointerCursor = mkIf cursor.enable {
    gtk.enable = true;
    name = cursor.name;
    package = cursor.package;
    size = cursor.size;
  };
}
