{ config
, nixosConfig
, lib
, ...
}:
let
  desktopCfg = config.modules.desktop;
  cfg = config.modules.desktop.dunst;
  colors = config.colorscheme.colors;
  osDesktopEnabled = nixosConfig.usrEnv.desktop.enable;
in
lib.mkIf (osDesktopEnabled && cfg.enable) {
  services.dunst = {
    enable = true;
    settings = {
      global = with desktopCfg.style; {
        monitor = builtins.toString cfg.monitorNumber;
        follow = "none";
        enable_posix_regex = true;
        font = "${desktopCfg.style.font.family} 13";
        icon_theme = config.gtk.iconTheme.name;
        show_indicators = true;
        format = "<b>%s</b>\\n<span font='10'>%b</span>";
        layer = "overlay";

        corner_radius = cornerRadius;
        width = builtins.floor ((lib.fetchers.primaryMonitor nixosConfig).width * 0.14);
        height = builtins.floor ((lib.fetchers.primaryMonitor nixosConfig).height * 0.25);
        offset = "${builtins.toString (gapSize * 2)}x${builtins.toString (gapSize * 2)}";
        gap_size = gapSize;
        frame_width = borderWidth;
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

      fullscreen_delay_everything = { fullscreen = "show"; };

      urgency_critical = {
        background = "#${colors.base00}b3";
        foreground = "#${colors.base07}";
        frame_color = "#${colors.base08}";
      };
      urgency_normal = {
        background = "#${colors.base00}b3";
        foreground = "#${colors.base07}";
        frame_color = "#${colors.base0E}";
      };
      urgency_low = {
        background = "#${colors.base00}b3";
        foreground = "#${colors.base07}";
        frame_color = "#${colors.base0D}";
      };
    };
  };

  desktop.hyprland.settings =
    lib.mkIf (desktopCfg.windowManager == "hyprland") {
      exec-once = [
        "${config.services.dunst.package}/bin/dunst"
      ];
      layerrule = [
        "blur, notifications"
        "xray 0, notifications"
      ];
    };
}
