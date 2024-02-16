{ lib
, pkgs
, config
, inputs
, vmVariant
, osConfig
, ...
}:
let
  inherit (lib) mkIf;
  cfg = desktopCfg.hyprland;
  desktopCfg = config.modules.desktop;
  hyprlandPackages = inputs.hyprland.packages.${pkgs.system};
  colors = config.colorscheme.palette;
  osDesktopEnabled = osConfig.usrEnv.desktop.enable;

  wlPaste = "${pkgs.wl-clipboard}/bin/wl-paste";
  xclip = "${pkgs.xclip}/bin/xclip";
in
mkIf (osDesktopEnabled && desktopCfg.windowManager == "hyprland") {
  home.packages = with pkgs; [
    hyprshot
  ];

  # Optimise for performance in VM variant
  modules.desktop.hyprland = lib.mkIf vmVariant (lib.mkVMOverride {
    tearing = false;
    blur = false;
    animations = false;
  });

  # Generate hyprland debug config
  home.activation.hyprlandDebugConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] /*bash*/ ''
    DEBUG_ARG=$([ -z "$VERBOSE_ARG" ] && echo "" || echo "--debug")
    run cat ${config.xdg.configHome}/hypr/hyprland.conf > ${config.xdg.configHome}/hypr/hyprlandd.conf \
      && ${lib.getExe pkgs.gnused} -i $DEBUG_ARG -e 's/${cfg.modKey}/${cfg.secondaryModKey}/g' \
      -e '/^exec-once/d' -e '/^monitor/d' -e 's/, monitor:(.*),//g' \
      ${lib.concatStringsSep " " (lib.lists.map (m: "-e 's/${m.name}/WL-${toString m.number}/g'") osConfig.device.monitors)} \
      ${config.xdg.configHome}/hypr/hyprlandd.conf \
      ${lib.concatStringsSep " " 
        (lib.lists.map 
          (m: "&& echo \"monitor=WL-${toString m.number},preferred,auto,1\" >> ${config.xdg.configHome}/hypr/hyprlandd.conf")
          osConfig.device.monitors)}
  '';

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
      ] ++ lib.lists.optionals (osConfig.device.gpu.type == "nvidia") [
        "LIBVA_DRIVER_NAME,nvidia"
        "GBM_BACKEND,nvidia-drm"
        "__GLX_VENDOR_LIBRARY_NAME,nvidia"
        "__GL_GSYNC_ALLOWED,0"
        "__GL_VRR_ALLOWED,0"
      ] ++ lib.lists.optional cfg.tearing "WLR_DRM_NO_ATOMIC,1";

      monitor = (lib.lists.map
        (
          m:
          if !m.enabled then
            "${m.name},disable"
          else
            lib.fetchers.getMonitorHyprlandCfgStr m
        )
        osConfig.device.monitors
      )
      ++ [
        ",preferred,auto,1" # automatic monitor detection
      ];

      # Launch apps
      exec-once = [
        "hyprctl dispatch focusmonitor ${(lib.fetchers.getMonitorByNumber osConfig 1).name}"
        # Temporary and buggy fix for fixing pasting into wine applications
        # Can remove xclip package once this is fixed
        # https://github.com/hyprwm/Hyprland/issues/2319
        # https://gitlab.freedesktop.org/wlroots/wlroots/-/merge_requests/4359
        # FIX: This is sometimes causing an extra linespace to be inserted on paste
        "${wlPaste} -t text -w sh -c 'v=$(${pkgs.coreutils}/bin/cat); ${pkgs.diffutils}/bin/cmp -s <(${xclip} -selection clipboard -o)  <<< \"$v\" || ${xclip} -selection clipboard <<< \"$v\"'"
      ];

      general = with desktopCfg.style; {
        gaps_in = gapSize / 2;
        gaps_out = gapSize;
        border_size = borderWidth;
        # True causes cursor to render over gamescope, I don't use it much anyway
        resize_on_border = false;
        hover_icon_on_border = false;
        "col.active_border" = "0xff${colors.base0D} 0xff${colors.base0E} 45deg";
        "col.inactive_border" = "0xff${colors.base00}";
        cursor_inactive_timeout = 5;
        allow_tearing = cfg.tearing;
      };

      windowrulev2 =
        let
          gameRegex = osConfig.modules.programs.gaming.windowClassRegex;
        in
        [
          "workspace name:GAME, class:${gameRegex}"

          "workspace name:VM silent, class:^(qemu)$"
          "float, class:^(qemu)$, title:^(QEMU.*)$"
          "size 75% 75%, class:^(qemu)$, title:^(QEMU.*)$"
          "center, class:^(qemu)$, title:^(QEMU.*)$"
          "keepaspectratio, class:^(qemu)$, title:^(QEMU.*)$"
        ] ++ lib.lists.optional cfg.tearing
          "immediate, class:${gameRegex}";

      decoration = {
        # Hyprland corner radius seems slightly stronger than CSS
        rounding = desktopCfg.style.cornerRadius - 2;

        blur = {
          enabled = cfg.blur;
          size = 2;
          passes = 3; # drop to 2 or 3 for weaker blur
          xray = true;
          special = true; # blur special workspace background
        };

        drop_shadow = false;
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
        enabled = cfg.animations;
        # Curves
        bezier = [
          "easeOutExpo,0.16,1,0.3,1"
          "easeInQuart,0.5,0,0.75,0"
          "easeOutQuart,0.25,1,0.5,1"
          "easeInOutQuart,0.76,0,0.24,1"
        ];
        animation = [
          # TODO: Window animations don't look great cause of the warping effect

          # Windows
          # "windowsIn,1,3,easeOutQuart"
          # "windowsOut,1,3,easeInQuart"
          # "windowsMove,1,3,easeInOutQuart"
          # Fade
          # "fade,1,1,easeInQuart"
          # "fadeOut,1,5,easeOutExpo"
          # Workspaces
          "workspaces,1,2,easeInOutQuart,slidevert"
        ];

      };

      misc = {
        disable_hyprland_logo = true;
        focus_on_activate = false;
        no_direct_scanout = !cfg.directScanout;
        mouse_move_enables_dpms = false;
        key_press_enables_dpms = true;
        background_color = "0xff${colors.base00}";
        new_window_takes_over_fullscreen = 2;
        enable_swallow = true;
        swallow_regex = "^(${desktopCfg.terminal.class})$";
      };

      dwindle = {
        preserve_split = true;
        force_split = 2;
        no_gaps_when_only = 1;
      };

      binds = {
        workspace_back_and_forth = true;
        movefocus_cycles_fullscreen = false;
        workspace_center_on = 1;
      };

      debug = {
        disable_logs = !cfg.logging;
      };

      workspace =
        let
          primaryMonitor = lib.fetchers.primaryMonitor osConfig;
        in
        (lib.lists.concatMap
          (
            m:
            let
              default = builtins.head m.workspaces;
            in
            (
              lib.lists.map
                (
                  w: "${toString w}, monitor:${m.name}" +
                  (if w == default then ", default:true" else "")
                )
                m.workspaces
            )
          )
          osConfig.device.monitors
        )
        ++ [
          "name:GAME, monitor:${primaryMonitor.name}"
          "name:VM, monitor:${primaryMonitor.name}"
          "special, gapsin:20, gapsout:40"
        ];
    };
  };
}
