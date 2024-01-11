{ config
, nixosConfig
, inputs
, pkgs
, lib
, ...
}:
let
  cfg = desktopCfg.hyprland;
  desktopCfg = config.modules.desktop;
  hyprlandPackages = inputs.hyprland.packages.${pkgs.system};
  colors = config.colorscheme.colors;
  osDesktopEnabled = nixosConfig.usrEnv.desktop.enable;
  inherit (lib) mkIf;
in
mkIf (osDesktopEnabled && desktopCfg.windowManager == "hyprland") {
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
    package = hyprlandPackages.hyprland.overrideAttrs (oldAttrs: {
      patches = (oldAttrs.patches or [ ]) ++ [ ../../../../../overlays/hyprlandOutputRename.diff ];
    });
    settings = {
      env = [
        "NIXOS_OZONE_WL,1"
        "XDG_CURRENT_DESKTOP=Hyprland"
        "XDG_SESSION_TYPE,wayland"
        "XDG_SESSION_DESKTOP=Hyprland"
        "WLR_NO_HARDWARE_CURSORS,1"
        "HYPRSHOT_DIR,${config.xdg.userDirs.pictures}/screenshots"
      ] ++ lib.lists.optionals (nixosConfig.device.gpu.type == "nvidia") [
        "LIBVA_DRIVER_NAME,nvidia"
        "GBM_BACKEND,nvidia-drm"
        "__GLX_VENDOR_LIBRARY_NAME,nvidia"
        "__GL_GSYNC_ALLOWED,0"
        "__GL_VRR_ALLOWED,0"
      ] ++ lib.lists.optional cfg.tearing "WLR_DRM_NO_ATOMIC,1";

      monitor = (lib.lists.map
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
        nixosConfig.device.monitors
      )
      ++ [
        ",preferred,auto,1" # automatic monitor detection
      ];

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
        allow_tearing = cfg.tearing;
      };

      windowrulev2 = mkIf cfg.tearing [
        "immediate, class:^(steam_app.*|cs2)$"
        "workspace name:GAME, class:^(steam_app.*|cs2)$"
      ];

      decoration = {
        # Hyprland corner radius seems slightly stronger than CSS
        rounding = desktopCfg.style.cornerRadius - 2;

        blur = {
          enabled = true;
          size = 2;
          passes = 3; # drop to 2 or 3 for weaker blur
          xray = true;
          special = true; # blur special workspace background
        };

        drop_shadow = false;

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
        # Curves
        bezier = [
          "easeOutExpo,0.16,1,0.3,1"
          "easeInQuart,0.5,0,0.75,0"
          "easeOutQuart,0.25,1,0.5,1"
          "easeInOutQuart,0.76,0,0.24,1"
        ];
        animation = [
          # Windows
          "windowsIn,1,3,easeOutQuart"
          "windowsOut,1,3,easeInQuart"
          "windowsMove,1,3,easeInOutQuart"
          # Fade
          "fade,1,1,easeInQuart"
          "fadeOut,1,5,easeOutExpo"
          # Workspaces
          "workspaces,1,2,easeInOutQuart,slidevert"
        ];

      };

      misc = {
        disable_hyprland_logo = true;
        focus_on_activate = false;
        mouse_move_enables_dpms = true;
        key_press_enables_dpms = true;
        background_color = "0xff${colors.base00}";
        new_window_takes_over_fullscreen = 2;
      };

      dwindle = {
        preserve_split = true;
        force_split = 2;
        no_gaps_when_only = 1;
      };

      binds = {
        workspace_back_and_forth = true;
        movefocus_cycles_fullscreen = false;
      };

      debug = {
        disable_logs = !cfg.logging;
      };

      workspace = (lib.lists.concatMap
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
        nixosConfig.device.monitors
      )
      ++ [
        "name:GAME,monitor:${(lib.fetchers.primaryMonitor nixosConfig).name},border:false" # automatic monitor detection
      ];
    };
  };
}
