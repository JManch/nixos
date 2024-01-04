{ config
, nixosConfig
, inputs
, pkgs
, lib
, ...
}:
let
  hyprlandPackages = inputs.hyprland.packages.${pkgs.system};
  desktopCfg = config.modules.desktop;
  colors = config.colorscheme.colors;
  osDesktopEnabled = nixosConfig.usrEnv.desktop.enable;
in
lib.mkIf (osDesktopEnabled && desktopCfg.windowManager == "hyprland") {
  home.packages = with pkgs; [
    hyprshot
    wl-clipboard
    xclip # For xwayland apps
  ];

  xdg.portal = {
    extraPortals = [ hyprlandPackages.xdg-desktop-portal-hyprland ];
    configPackages = [ hyprlandPackages.hyprland ];
  };

  wayland.windowManager.hyprland = {
    enable = true;
    package = hyprlandPackages.hyprland;
    settings = {
      env = [
        "NIXOS_OZONE_WL,1"
        "XDG_CURRENT_DESKTOP=Hyprland"
        "XDG_SESSION_TYPE,wayland"
        "XDG_SESSION_DESKTOP=Hyprland"
        "WLR_NO_HARDWARE_CURSORS,1"
        "HYPRSHOT_DIR,${config.xdg.userDirs.pictures}/screenshots"
      ] ++ lib.lists.optionals (nixosConfig.device.gpu == "nvidia") [
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
        nixosConfig.device.monitors;

      # Launch apps
      exec-once = [
        "hyprctl dispatch focusmonitor ${(lib.fetchers.getMonitorByNumber nixosConfig 1).name}"
        # Temporary and buggy fix for fixing pasting into wine applications
        # Can remove xclip package once this is fixed
        # https://github.com/hyprwm/Hyprland/issues/2319
        # https://gitlab.freedesktop.org/wlroots/wlroots/-/merge_requests/4359
        "wl-paste -t text -w sh -c 'v=$(cat); cmp -s <(xclip -selection clipboard -o)  <<< \"$v\" || xclip -selection clipboard <<< \"$v\"'"
      ];

      general = with desktopCfg.style; {
        gaps_in = gapSize / 2;
        gaps_out = gapSize;
        border_size = borderWidth;
        resize_on_border = true;
        hover_icon_on_border = false;
        "col.active_border" = "0xff${colors.base0D}";
        "col.inactive_border" = "0xff${colors.base00}";

        cursor_inactive_timeout = 0;
      };

      decoration = {
        # Hyprland corner radius seems slightly stronger than CSS
        rounding = desktopCfg.style.cornerRadius - 2;

        blur = {
          enabled = true;
          size = 2;
          passes = 2;
          xray = true;
        };

        drop_shadow = false;
        shadow_range = 10;
        shadow_render_power = 2;
        "col.shadow" = "0xff${colors.base0D}";

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
        nixosConfig.device.monitors;
    };
  };
}
