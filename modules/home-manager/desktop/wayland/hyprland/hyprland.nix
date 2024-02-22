{ lib
, pkgs
, config
, osConfig
, vmVariant
, ...
} @ args:
let
  inherit (lib)
    mkIf
    utils
    mkVMOverride
    getExe
    concatStringsSep
    concatMap
    head
    optional
    optionals
    fetchers;
  inherit (osConfig.device) monitors;

  cfg = desktopCfg.hyprland;
  desktopCfg = config.modules.desktop;
  colors = config.colorscheme.palette;
  osDesktopEnabled = osConfig.usrEnv.desktop.enable;

  hyprlandPackages = utils.flakePkgs args "hyprland";
in
mkIf (osDesktopEnabled && desktopCfg.windowManager == "Hyprland") {
  # Optimise for performance in VM variant
  modules.desktop.hyprland = mkIf vmVariant (mkVMOverride {
    tearing = false;
    blur = false;
    animations = false;
  });

  # Generate hyprland debug config
  home.activation.hyprlandDebugConfig =
    let
      hyprDir = "${config.xdg.configHome}/hypr";
    in
    lib.hm.dag.entryAfter [ "writeBoundary" ] /*bash*/ ''

      DEBUG_ARG=$([ -z "$VERBOSE_ARG" ] && echo "" || echo "--debug")
      run cat ${hyprDir}/hyprland.conf > ${hyprDir}/hyprlandd.conf \
        && ${getExe pkgs.gnused} -i $DEBUG_ARG -e 's/${cfg.modKey}/${cfg.secondaryModKey}/g' \
        -e '/^exec-once/d' -e '/^monitor/d' -e 's/, monitor:(.*),//g' \
        ${concatStringsSep " " (map (m: "-e 's/${m.name}/WL-${toString m.number}/g'") monitors)} \
        ${hyprDir}/hyprlandd.conf \
        ${concatStringsSep " " 
          (map 
            (m: "&& echo \"monitor=WL-${toString m.number},preferred,auto,1\" >> ${hyprDir}/hyprlandd.conf")
            monitors)}

    '';

  xdg.portal = {
    extraPortals = [ hyprlandPackages.xdg-desktop-portal-hyprland ];
    configPackages = [ hyprlandPackages.hyprland ];
  };

  wayland.windowManager.hyprland = {
    enable = true;
    # By default Hyprland adds stdenv.cc, binutils and pciutils to path. I
    # think it's to fix plugin API function hooking.
    # https://github.com/hyprwm/Hyprland/pull/2292 
    # Since I don't use plugins I can use the unwrapped package and keep my
    # path clean.
    # WARNING: If you ever want to use plugins switch to the wrapped package
    package = hyprlandPackages.hyprland-unwrapped;

    settings = {
      env = [
        "NIXOS_OZONE_WL,1"
        "XDG_CURRENT_DESKTOP=Hyprland"
        "XDG_SESSION_TYPE,wayland"
        "XDG_SESSION_DESKTOP=Hyprland"
        "HYPRSHOT_DIR,${config.xdg.userDirs.pictures}/screenshots"
      ] ++ optionals (osConfig.device.gpu.type == "nvidia") [
        "WLR_NO_HARDWARE_CURSORS,1"
        "LIBVA_DRIVER_NAME,nvidia"
        "GBM_BACKEND,nvidia-drm"
        "__GLX_VENDOR_LIBRARY_NAME,nvidia"
        "__GL_GSYNC_ALLOWED,0"
        "__GL_VRR_ALLOWED,0"
      ] ++ optional cfg.tearing "WLR_DRM_NO_ATOMIC,1";

      monitor = (map
        (
          m:
          if !m.enabled then
            "${m.name},disable"
          else
            fetchers.getMonitorHyprlandCfgStr m
        )
        monitors
      ) ++ [
        ",preferred,auto,1" # automatic monitor detection
      ];

      exec-once =
        let
          xclip = getExe pkgs.xclip;
          hyprctl = "${config.wayland.windowManager.hyprland.package}/bin/hyprctl";
          wlPaste = "${pkgs.wl-clipboard}/bin/wl-paste";
          cat = "${pkgs.coreutils}/bin/cat";
          cmp = "${pkgs.diffutils}/bin/cmp";
        in
        [
          "${hyprctl} dispatch focusmonitor ${(fetchers.getMonitorByNumber osConfig 1).name}"
          # Temporary and buggy fix for pasting into wine applications
          # https://github.com/hyprwm/Hyprland/issues/2319
          # https://gitlab.freedesktop.org/wlroots/wlroots/-/merge_requests/4359
          # FIX: This is sometimes causing an extra linespace to be inserted on paste
          "${wlPaste} -t text -w sh -c 'v=$(${cat}); ${cmp} -s <(${xclip} -selection clipboard -o)  <<< \"$v\" || ${xclip} -selection clipboard <<< \"$v\"'"
        ];

      general = with desktopCfg.style; {
        gaps_in = gapSize / 2;
        gaps_out = gapSize;
        border_size = borderWidth;
        resize_on_border = true;
        hover_icon_on_border = false;
        "col.active_border" = "0xff${colors.base0D} 0xff${colors.base0E} 45deg";
        "col.inactive_border" = "0xff${colors.base00}";
        cursor_inactive_timeout = 3;
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
        rounding = desktopCfg.style.cornerRadius - 2;
        drop_shadow = false;

        blur = {
          enabled = cfg.blur;
          size = 2;
          passes = 3;
          xray = true;
          special = true;
        };
      };

      input = {
        follow_mouse = 1;
        mouse_refocus = false;
        accel_profile = "flat";
        sensitivity = 0;

        kb_layout = "us";
        repeat_delay = 500;
        repeat_rate = 30;
      };

      animations = {
        enabled = cfg.animations;

        bezier = [
          # "easeOutExpo,0.16,1,0.3,1"
          # "easeInQuart,0.5,0,0.75,0"
          # "easeOutQuart,0.25,1,0.5,1"
          "easeInOutQuart,0.76,0,0.24,1"
        ];
        animation = [
          # TODO: Add better animations
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
        allow_workspace_cycles = true;
        movefocus_cycles_fullscreen = false;
        workspace_center_on = 1;
      };

      debug = {
        disable_logs = !cfg.logging;
      };

      workspace =
        let
          inherit (desktopCfg.style) gapSize;
          primaryMonitor = fetchers.primaryMonitor osConfig;
        in
        (concatMap
          (
            m:
            let
              default = head m.workspaces;
            in
            (
              map
                (
                  w: "${toString w}, monitor:${m.name}" +
                  (if w == default then ", default:true" else "")
                )
                m.workspaces
            )
          )
          monitors
        ) ++ [
          "name:GAME, monitor:${primaryMonitor.name}"
          "name:VM, monitor:${primaryMonitor.name}"
          "special, gapsin:${toString (gapSize * 2)}, gapsout:${toString (gapSize * 4)}"
        ];
    };
  };
}
