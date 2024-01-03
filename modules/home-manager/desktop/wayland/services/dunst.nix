{ config
, osConfig
, lib
, ...
}:
let
  isWayland = lib.validators.isWayland osConfig;
  cfg = config.modules.desktop.dunst;
  colors = config.colorscheme.colors;
  hyprlandSettings = config.wayland.windowManager.hyprland.settings;
in
# TODO:Move this entire module out of wayland as dunst can be used on wayland or x11
lib.mkIf (isWayland && cfg.enable) {
  services.dunst = {
    enable = true;
    settings = {
      global = {
        monitor = "0";
        follow = "none";
        enable_posix_regex = true;
        font = "${config.modules.desktop.font.family} 11";
        icon_theme = config.gtk.iconTheme.name;
        show_indicators = true;

        # TODO: Move the corner radius for waybar and this into a global option
        corner_radius = 10;
        width = builtins.floor ((lib.fetchers.primaryMonitor osConfig).width * 0.15);
        height = builtins.floor ((lib.fetchers.primaryMonitor osConfig).height * 0.25);
        # TODO: Move these hyprland settings out into global desktop options
        offset = "${builtins.toString (hyprlandSettings.general.gaps_out * 2)}x${builtins.toString (hyprlandSettings.general.gaps_out*2)}";
        gap_size = hyprlandSettings.general.gaps_out;
        frame_width = hyprlandSettings.general.border_size;
        transparency = 100;

        mouse_left_click = "do_action";
        mouse_middle_click = "close_all";
        mouse_right_click = "close_current";
        sort = true;
        stack_duplicates = true;
        min_icon_size = 128;
        max_icon_size = 128;
        markup = "full";
      };

      fullscreen_delay_everything = { fullscreen = "delay"; };

      urgency_critical = {
        background = "#${colors.base00}b3";
        foreground = "#${colors.base05}";
        frame_color = "#${colors.base08}";
      };
      urgency_low = {
        background = "#${colors.base00}b3";
        foreground = "#${colors.base05}";
        frame_color = "#${colors.base00}b3";
      };
      urgency_normal = {
        background = "#${colors.base00}b3";
        foreground = "#${colors.base05}";
        frame_color = "#${colors.base0D}";
      };
    };
  };

  wayland.windowManager.hyprland.settings = lib.mkIf (osConfig.usrEnv.desktop.compositor == "hyprland") {
    exec-once = [
      "dunst"
    ];
    layerrule = [
      "blur, notifications"
      "xray 0, notifications"
    ];
  };
}
