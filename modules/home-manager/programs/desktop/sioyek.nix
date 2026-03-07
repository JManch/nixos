{
  lib,
  pkgs,
  config,
}:
{
  home.packages = [ pkgs.sioyek ];

  xdg.configFile."sioyek/prefs_user.config".text = ''
    ui_font ${config.${lib.ns}.desktop.style.font.family}
  '';

  xdg.configFile."sioyek/keys_user.config".text = ''
    next_page;goto_top_of_page j
    prev_page k
    move_visual_mark_down <C-j>
    move_visual_mark_up <C-k>
    move_down_smooth J
    move_up_smooth K
    screen_down_smooth <C-d>
    screen_up_smooth <C-u>
    toggle_dark_mode <C-l>
  '';

  xdg.mimeApps.defaultApplications = {
    "application/pdf" = [ "sioyek.desktop" ];
  };
}
