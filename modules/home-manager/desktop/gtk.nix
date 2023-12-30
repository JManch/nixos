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
      package = pkgs.plata-theme;
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

  wayland.windowManager.hyprland.settings.env =
    lib.mkIf (osConfig.usrEnv.desktop.compositor == "hyprland") [
      "XCURSOR_THEME,Bibata-Modern-Classic"
      "XCURSOR_SIZE,${builtins.toString config.modules.desktop.cursorSize}"
    ];
}
