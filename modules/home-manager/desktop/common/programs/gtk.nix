{
  lib,
  pkgs,
  config,
  inputs,
  desktopEnabled,
  ...
}:
let
  inherit (lib)
    ns
    mkIf
    getExe'
    hiPrio
    optionals
    optionalString
    ;
  inherit (config.${ns}) colorScheme;
  inherit (cfg.style) cursor customTheme;
  inherit (inputs.nix-colors.lib-contrib { inherit pkgs; }) gtkThemeFromScheme;
  cfg = config.${ns}.desktop;

  # Rather than generating a custom gtk.css file from our base16 colorscheme
  # like stylix does, we generate patched versions of Materia. This is because
  # using gtk.css does not allow hot-reloading when switching between light and
  # dark theme variants.
  # https://github.com/danth/stylix/blob/963e77a3a4fc2be670d5a9a6cbeb249b8a43808a/modules/gtk/gtk.mustache#L3
  darkTheme = gtkThemeFromScheme { scheme = colorScheme.dark; };
  lightTheme = gtkThemeFromScheme { scheme = colorScheme.light; };
in
mkIf desktopEnabled {
  home.packages =
    [
      (hiPrio (
        pkgs.runCommand "xdg-desktop-portal-gtk-session-slice" { } ''
          install -Dm644 ${pkgs.xdg-desktop-portal-gtk}/share/systemd/user/xdg-desktop-portal-gtk.service -t $out/share/systemd/user
          echo "Slice=session.slice" >> $out/share/systemd/user/xdg-desktop-portal-gtk.service
          chmod 444 $out/share/systemd/user/xdg-desktop-portal-gtk.service
        ''
      ))
    ]
    ++ optionals customTheme [
      darkTheme
      lightTheme
    ];

  gtk = {
    enable = true;

    theme = mkIf customTheme {
      name = colorScheme.dark.slug;
      # We do not set the package here because it causes home manager to
      # generate a gtk-4.0/gtk.css file. Unfortunately this results in broken
      # GTK 4 theming that does not respond to light/dark theme switches
      # (because gtk.css themes cannot be hot-reloaded). Just gonna give up on
      # GTK 4 theming and use Adwaita (the default) in GTK 4 apps.
      # https://github.com/nix-community/home-manager/blob/2f23fa308a7c067e52dfcc30a0758f47043ec176/modules/misc/gtk.nix#L239
    };

    iconTheme = mkIf customTheme {
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
      ${optionalString customTheme "${gsettings} set org.gnome.desktop.interface gtk-theme ${colorScheme.${theme}.slug}"}
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
