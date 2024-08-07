{
  lib,
  pkgs,
  config,
  osConfig',
  vmVariant,
  ...
}@args:
let
  inherit (lib)
    mkIf
    utils
    mkVMOverride
    getExe
    getExe'
    concatMapStringsSep
    concatMap
    imap
    optionalString
    optionals
    ;
  inherit (osConfig'.device) monitors primaryMonitor;
  inherit (desktopCfg.style) gapSize borderWidth;

  cfg = desktopCfg.hyprland;
  desktopCfg = config.modules.desktop;
  colors = config.colorScheme.palette;

  hyprlandPkgs = utils.flakePkgs args "hyprland";

  # Patch makes the togglespecialworkspace dispatcher always toggle instead
  # of moving the open special workspace to the active monitor
  hyprland = utils.addPatches hyprlandPkgs.hyprland [
    ../../../../../patches/hyprlandSpecialWorkspaceToggle.patch
    ../../../../../patches/hyprlandEmptyMonitorFix.patch
    ../../../../../patches/hyprlandDispatcherError.patch
  ];
in
mkIf (utils.isHyprland config) {
  assertions = utils.asserts [
    (!(osConfig'.xdg.portal.enable or false))
    "The os xdg portal must be disabled when using Hyprland as it is configured using home-manager"
  ];

  modules.desktop = {
    # Optimise for performance in VM variant
    # TODO: When I update hyprland, add a hook to disable hardware cursors when
    # launching a QEMU VM otherwise the cursor is upside down.
    # https://github.com/hyprwm/Hyprland/issues/6428
    hyprland = mkIf vmVariant (mkVMOverride {
      tearing = false;
      directScanout = false;
      blur = false;
      animations = false;
    });
  };

  home.packages = [ (utils.flakePkgs args "grimblast").grimblast ];

  # Install Hyprcursor package
  home.file = mkIf (cfg.hyprcursor.package != null) {
    ".icons/${cfg.hyprcursor.name}".source = "${cfg.hyprcursor.package}/share/icons/${cfg.hyprcursor.name}";
  };

  # Generate hyprland debug config
  xdg.configFile."hypr/hyprland.conf".onChange =
    let
      hyprDir = "${config.xdg.configHome}/hypr";
    in
    # bash
    ''
      ${getExe pkgs.gnused} \
        -e 's/${cfg.modKey}/${cfg.secondaryModKey}/g' \
        -e 's/enable_stdout_logs=false/enable_stdout_logs=true/' \
        -e 's/disable_hyprland_logo=true/disable_hyprland_logo=false/' \
        -e 's/no_direct_scanout=false/no_direct_scanout=true/' \
        -e '/ALTALT/d' \
        -e '/screen_shader/d' \
        -e '/^exec-once/d' \
        -e '/^monitor/d' \
        -e 's/, monitor:(.*),//g' \
        ${concatMapStringsSep " " (m: "-e 's/${m.name}/WL-${toString m.number}/g'") monitors} \
        ${hyprDir}/hyprland.conf > ${hyprDir}/hyprlandd.conf
      ${
        # Add monitor config
        concatMapStringsSep "\n" (
          m:
          let
            res = "${toString m.width}x${toString m.height}";
          in
          "echo \"monitor=WL-${toString m.number},${res},${toString m.position.x}x${toString m.position.y},1\" >> ${hyprDir}/hyprlandd.conf"
        ) monitors
      }
    '';

  xdg.portal = {
    enable = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-gtk
      hyprlandPkgs.xdg-desktop-portal-hyprland
    ];
    configPackages = [ hyprland ];
  };

  wayland.windowManager.hyprland = {
    enable = true;
    package = hyprland;

    # plugins = with utils.flakePkgs args "hyprland-plugins"; [
    #   hyprexpo
    # ];

    systemd = {
      enable = true;
      extraCommands = [
        # This works because hyprland-session.target BindsTo
        # graphical-session.target so starting hyprland-session.target also
        # starts graphical-session.target. We stop graphical-session.target
        # instead of hyprland-session.target because, by default, home-manager
        # services bind to graphical-session.target. Also, we basically ignore
        # hyprland-session.target in our config because we manage modularity in
        # Nix rather than with systemd.
        # https://github.com/nix-community/home-manager/issues/4484
        "systemctl --user stop graphical-session.target"
        "systemctl --user start hyprland-session.target"
      ];
    };

    settings = {
      env =
        [
          "XDG_CURRENT_DESKTOP,Hyprland"
          "XDG_SESSION_TYPE,wayland"
          "XDG_SESSION_DESKTOP,Hyprland"
          # Disable for cursor on mirrored monitors. After update should be able
          # to toggle this at runtime.
          "WLR_NO_HARDWARE_CURSORS,1"
        ]
        ++ optionals (cfg.hyprcursor.package != null) [
          "HYPRCURSOR_THEME,${cfg.hyprcursor.name}"
          "HYPRCURSOR_SIZE,${toString config.modules.desktop.style.cursor.size}"
        ]
        ++ optionals (osConfig'.device.gpu.type == "nvidia") [
          "LIBVA_DRIVER_NAME,nvidia"
          "GBM_BACKEND,nvidia-drm"
          "__GLX_VENDOR_LIBRARY_NAME,nvidia"
          "__GL_GSYNC_ALLOWED,0"
          "__GL_VRR_ALLOWED,0"
        ];

      monitor =
        (map (m: if !m.enabled then "${m.name},disable" else utils.getMonitorHyprlandCfgStr m) monitors)
        ++ [
          ",preferred,auto,1" # automatic monitor detection
        ];

      exec-once =
        let
          xclip = getExe pkgs.xclip;
          wlPaste = getExe' pkgs.wl-clipboard "wl-paste";
          cat = getExe' pkgs.coreutils "cat";
          cmp = getExe' pkgs.diffutils "cmp";
        in
        [
          # Temporary and buggy fix for pasting into wine applications
          # https://github.com/hyprwm/Hyprland/issues/2319
          # https://gitlab.freedesktop.org/wlroots/wlroots/-/merge_requests/4359
          # FIX: This is sometimes causing an extra linespace to be inserted on paste
          "${wlPaste} -t text -w sh -c 'v=$(${cat}); ${cmp} -s <(${xclip} -selection clipboard -o)  <<< \"$v\" || ${xclip} -selection clipboard <<< \"$v\"'"
        ];

      general = {
        gaps_in = gapSize / 2;
        gaps_out = gapSize;
        border_size = borderWidth;
        extend_border_grab_area = gapSize / 2;
        resize_on_border = true;
        hover_icon_on_border = false;
        "col.active_border" = "0xff${colors.base0D}";
        "col.inactive_border" = "0xff${colors.base00}";
        allow_tearing = cfg.tearing;
        cursor_inactive_timeout = 3;
      };

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

        tablet =
          let
            inherit (primaryMonitor) position width height;
          in
          {
            # Custom transforms are currently broken
            transform = 1;
            region_position = "${toString position.x} ${toString position.y}";
            region_size = "${toString width} ${toString height}";
          };
      };

      animations = {
        enabled = cfg.animations;

        bezier = [
          "easeInOutQuart,0.76,0,0.24,1"
          "fluent_decel, 0, 0.2, 0.4, 1"
          "easeOutCirc, 0, 0.55, 0.45, 1"
          "easeOutCubic, 0.33, 1, 0.68, 1"
          "easeinoutsine, 0.37, 0, 0.63, 1"
        ];

        animation = [
          "windowsIn,1,3,easeOutCubic, popin 30%"
          "windowsOut,1,3,fluent_decel, popin 70%"
          "windowsMove,1,2,easeinoutsine, slide"
          "fadeIn, 1, 3, easeOutCubic"
          "fadeOut, 1, 1.7, easeOutCubic"
          "fadeSwitch, 0, 1, easeOutCirc"
          "fadeShadow, 1, 10, easeOutCirc"
          "fadeDim, 1, 4, fluent_decel"
          "border, 1, 2.7, easeOutCirc"
          "borderangle, 1, 30, fluent_decel, once"
          "workspaces, 1, 3, easeOutCubic, slidevert"
        ];
      };

      misc = {
        disable_autoreload = true;
        disable_hyprland_logo = true;
        focus_on_activate = false;
        no_direct_scanout = !cfg.directScanout;
        mouse_move_enables_dpms = true;
        key_press_enables_dpms = true;
        background_color = "0xff${colors.base00}";
        new_window_takes_over_fullscreen = 2;
        enable_swallow = false;
        swallow_regex = "^(${desktopCfg.terminal.class})$";
        enable_hyprcursor = cfg.hyprcursor.package != null;
        hide_cursor_on_key_press = true;
      };

      dwindle = {
        preserve_split = true;
        force_split = 2;
        no_gaps_when_only = 0; # currently broken https://github.com/hyprwm/Hyprland/issues/5552
      };

      binds = {
        workspace_back_and_forth = true;
        allow_workspace_cycles = true;
        movefocus_cycles_fullscreen = false;
        workspace_center_on = 1;
      };

      debug = {
        disable_logs = !cfg.logging;
        enable_stdout_logs = false;
      };

      workspace =
        (concatMap (
          m:
          (imap (
            i: w:
            "${toString w}, monitor:${m.name}"
            + optionalString (i == 1) ", default:true"
            + optionalString (i < 3) ", persistent:true"
          ) m.workspaces)
        ) monitors)
        ++ [
          "name:GAME, monitor:${primaryMonitor.name}"
          "name:VM, monitor:${primaryMonitor.name}"
          "special:social, gapsin:${toString (gapSize * 2)}, gapsout:${toString (gapSize * 4)}"
        ];

      # plugin = {
      #   hyprexpo = {
      #     columns = 3;
      #     gap_size = 0;
      #     workspace_method = "first m~1";
      #     enable_gesture = false;
      #   };
      # };
    };
  };

  darkman.switchApps.hyprland =
    let
      inherit (config.modules.colorScheme) colorMap dark;
      hyprctl = getExe' config.wayland.windowManager.hyprland.package "hyprctl";
      mapDarkColor = base: colorMap.${base} // { light = dark.palette.${base}; };
    in
    {
      paths = [ "hypr/hyprland.conf" ];
      # Only reload if gamemode is not active to avoid overriding
      # gamemode-specific hyprland settings
      reloadScript = "${getExe' pkgs.gamemode "gamemoded"} --status | grep 'is active' -q || ${hyprctl} reload";
      colors = colorMap // {
        base00 = mapDarkColor "base00";
        base01 = mapDarkColor "base01";
        base02 = mapDarkColor "base02";
        base03 = mapDarkColor "base03";
        base04 = mapDarkColor "base04";
        base05 = mapDarkColor "base05";
        base06 = mapDarkColor "base06";
        base07 = mapDarkColor "base07";
      };
    };

  programs.zsh.shellAliases = {
    hyprland-setup-dev = "cmake -DCMAKE_EXPORT_COMPILE_COMMANDS=ON -DCMAKE_BUILD_TYPE=Debug -B build";
  };
}
