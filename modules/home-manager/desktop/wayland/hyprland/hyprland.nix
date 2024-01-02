{ config
, osConfig
, inputs
, pkgs
, lib
, ...
}:
let
  desktopCfg = osConfig.usrEnv.desktop;
in
lib.mkIf (desktopCfg.enable && desktopCfg.compositor == "hyprland") {
  modules.desktop.sessionTarget = "hyprland-session.target";

  home.packages = with pkgs; [
    hyprshot
    swww
    wl-clipboard
    xclip # For xwayland apps
  ];

  assertions = [
    {
      assertion = (lib.length osConfig.device.monitors) != 0;
      message = "Monitors must be configured to use Hyprland.";
    }
  ];

  wayland.windowManager.hyprland = {
    enable = true;
    package = inputs.hyprland.packages.${pkgs.system}.default;
    settings = {
      env = [
        "NIXOS_OZONE_WL,1"
        "XDG_CURRENT_DESKTOP=Hyprland"
        "XDG_SESSION_TYPE,wayland"
        "XDG_SESSION_DESKTOP=Hyprland"
        "WLR_NO_HARDWARE_CURSORS,1"
        "HYPRSHOT_DIR,${config.xdg.userDirs.pictures}/screenshots"
      ] ++ lib.lists.optionals (osConfig.device.gpu == "nvidia") [
        "LIBVA_DRIVER_NAME,nvidia"
        "GBM_BACKEND,nvidia-drm"
        "__GLX_VENDOR_LIBRARY_NAME,nvidia"
      ];

      monitor = lib.lists.map
        (
          m:
          "${m.name}, " +
          (
            if !m.enabled
            then
              "disable"
            else
              "${builtins.toString m.width}x${builtins.toString m.height}@${builtins.toString m.refreshRate}, ${m.position}, 1"
          )
        )
        osConfig.device.monitors;

      # Launch apps
      exec-once = [
        "hyprctl dispatch focusmonitor ${(lib.fetchers.getMonitorByNumber osConfig 1).name}"
        "sleep 1 && ${pkgs.swww}/bin/swww init"
        # Temporary and buggy fix for fixing pasting into wine applications
        # Can remove xclip package once this is fixed
        # https://github.com/hyprwm/Hyprland/issues/2319
        # https://gitlab.freedesktop.org/wlroots/wlroots/-/merge_requests/4359
        "wl-paste -t text -w sh -c 'v=$(cat); cmp -s <(xclip -selection clipboard -o)  <<< \"$v\" || xclip -selection clipboard <<< \"$v\"'"
      ];

      general = {
        gaps_in = 5;
        gaps_out = 10;
        border_size = 2;
        resize_on_border = true;
        hover_icon_on_border = false;
        "col.active_border" = "0xff${config.colorscheme.colors.base0D}";
        "col.inactive_border" = "0xff${config.colorscheme.colors.base00}";

        cursor_inactive_timeout = 0;
      };

      decoration = {
        rounding = 10;

        blur = {
          enabled = true;
          size = 2;
          passes = 2;
          xray = true;
        };

        drop_shadow = false;
        shadow_range = 10;
        shadow_render_power = 2;
        "col.shadow" = "0xff${config.colorscheme.colors.base0D}";

        screen_shader = "${config.xdg.configHome}/hypr/shaders/monitor1_gamma.frag";
      };

      input = {
        follow_mouse = 1;
        mouse_refocus = false;

        kb_layout = "us";
        repeat_delay = 500;
        repeat_rate = 30;

        accel_profile = "flat";
        sensitivity = 0;
      };

      animations = {
        enabled = true;
        # TODO: Configure animations to my liking
      };

      misc = {
        disable_hyprland_logo = true;
        focus_on_activate = false;
        mouse_move_enables_dpms = true;
        key_press_enables_dpms = true;
      };

      dwindle = {
        preserve_split = true;
        force_split = 2;
      };

      binds = {
        workspace_back_and_forth = true;
      };

      workspace = lib.lists.concatMap
        (
          m:
          let
            default = builtins.head m.workspaces;
          in
          (
            lib.lists.map
              (
                w: "${builtins.toString w}, monitor:${m.name}" +
                  (if w == default then ", default:true" else "")
              )
              m.workspaces
          )
        )
        osConfig.device.monitors;
    };
  };
}
