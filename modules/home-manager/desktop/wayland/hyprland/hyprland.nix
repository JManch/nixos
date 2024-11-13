{
  ns,
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
    mkVMOverride
    getExe
    getExe'
    concatMapStringsSep
    concatMap
    imap
    attrNames
    optionalString
    optionals
    mapAttrsToList
    ;
  inherit (lib.${ns})
    flakePkgs
    addPatches
    isHyprland
    asserts
    getMonitorHyprlandCfgStr
    ;
  inherit (osConfig'.${ns}.device) monitors primaryMonitor;
  inherit (desktopCfg.style) gapSize borderWidth;

  cfg = desktopCfg.hyprland;
  desktopCfg = config.${ns}.desktop;
  colors = config.colorScheme.palette;

  hyprlandPkgs = flakePkgs args "hyprland";

  # Patch makes the togglespecialworkspace dispatcher always toggle instead
  # of moving the open special workspace to the active monitor
  hyprlandPkg = addPatches hyprlandPkgs.hyprland [
    ../../../../../patches/hyprlandSpecialWorkspaceToggle.patch
    ../../../../../patches/hyprlandResizeParamsFloats.patch
    # Potential fix for https://github.com/hyprwm/Hyprland/issues/6820
    ../../../../../patches/hyprlandSpecialWorkspaceFullscreen.patch
    # Fixes center and size/move window rules using the active monitor instead
    # of the monitor that the window is on
    ../../../../../patches/hyprlandWindowRuleMonitor.patch
    # Makes exact resizeparams in dispatchers relative to the window's current
    # monitor instead of the last active monitor
    ../../../../../patches/hyprlandBetterResizeArgs.patch
  ];
in
mkIf (isHyprland config) {
  assertions = asserts [
    (!(osConfig'.xdg.portal.enable or false))
    "The os xdg portal must be disabled when using Hyprland as it is configured using home-manager"
  ];

  ${ns}.desktop = {
    # Optimise for performance in VM variant
    hyprland = mkIf vmVariant (mkVMOverride {
      tearing = false;
      directScanout = false;
      blur = false;
      animations = false;
    });
  };

  home.packages =
    [ (flakePkgs args "grimblast").grimblast ]
    # These are needed for xdg-desktop-portal-hyprland screenshot
    # functionality. Even though I use grimblast the portal may be used in some
    # situations?
    ++ (with pkgs; [
      grim
      slurp
      hyprpicker
    ]);

  # Install Hyprcursor package
  home.file = mkIf (cfg.hyprcursor.package != null) {
    ".icons/${cfg.hyprcursor.name}".source = "${cfg.hyprcursor.package}/share/icons/${cfg.hyprcursor.name}";
  };

  # Generate hyprland debug config
  xdg.configFile."hypr/hyprland.conf".onChange =
    let
      hyprDir = "${config.xdg.configHome}/hypr";
      m = primaryMonitor;
    in
    # bash
    ''
      ${getExe pkgs.gnused} \
        -e 's/${cfg.modKey}/${cfg.secondaryModKey}/g' \
        -e 's/enable_stdout_logs=false/enable_stdout_logs=true/' \
        -e 's/disable_hyprland_logo=true/disable_hyprland_logo=false/' \
        -e 's/direct_scanout=false/direct_scanout=true/' \
        -e '/ALTALT/d' \
        -e '/screen_shader/d' \
        -e '/^exec-once/d' \
        -e '/^monitor/d' \
        -e 's/, monitor:(.*),//g' \
        -e 's/${primaryMonitor.name}/WAYLAND-1/g' \
        ${hyprDir}/hyprland.conf > ${hyprDir}/hyprlandd.conf

      # Add monitor config
      echo "monitor=WAYLAND-${toString m.number},${toString m.width}x${toString m.height},${toString m.position.x}x${toString m.position.y},1" >> ${hyprDir}/hyprlandd.conf
    '';

  xdg.portal = {
    enable = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-gtk
      hyprlandPkgs.xdg-desktop-portal-hyprland
    ];
    configPackages = [ hyprlandPkg ];
  };

  wayland.windowManager.hyprland = {
    enable = true;
    package = hyprlandPkg;

    plugins = optionals cfg.plugins.enable (with flakePkgs args "hyprland-plugins"; [ hyprexpo ]);

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
        ]
        ++ optionals (cfg.hyprcursor.package != null) [
          "HYPRCURSOR_THEME,${cfg.hyprcursor.name}"
          "HYPRCURSOR_SIZE,${toString config.${ns}.desktop.style.cursor.size}"
        ]
        ++ optionals (osConfig'.${ns}.device.gpu.type == "nvidia") [
          "LIBVA_DRIVER_NAME,nvidia"
          "GBM_BACKEND,nvidia-drm"
          "__GLX_VENDOR_LIBRARY_NAME,nvidia"
          "__GL_GSYNC_ALLOWED,0"
          "__GL_VRR_ALLOWED,0"
        ];

      monitor =
        (map (m: if !m.enabled then "${m.name},disable" else getMonitorHyprlandCfgStr m) monitors)
        ++ [
          ",preferred,auto,1" # automatic monitor detection
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
      };

      decoration = {
        rounding = desktopCfg.style.cornerRadius - 2;
        shadow.enabled = false;

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
        mouse_refocus = true;
        accel_profile = "flat";
        sensitivity = 0;

        kb_layout = "us";
        repeat_delay = 500;
        repeat_rate = 30;

        tablet = {
          output = "current";
          transform = 1;
        };
      };

      cursor = {
        inactive_timeout = 0;
        enable_hyprcursor = cfg.hyprcursor.package != null;
        hide_on_key_press = false;
      };

      animations = {
        enabled = cfg.animations;

        bezier = [
          "easeInOutQuart,0.76,0,0.24,1"
          "fluentDecel, 0, 0.2, 0.4, 1"
          "easeOutCirc, 0, 0.55, 0.45, 1"
          "easeOutCubic, 0.33, 1, 0.68, 1"
          "easeinoutsine, 0.37, 0, 0.63, 1"
          "easeOutQuint, 0.23, 1, 0.32, 1"
        ];

        animation = [
          "windowsIn, 1, 3, easeOutCubic, popin 30%"
          "windowsOut, 1, 3, fluentDecel, popin 70%"
          "windowsMove, 1, 4, easeOutQuint"
          "fadeIn, 1, 3, easeOutCubic"
          "fadeOut, 1, 1.7, easeOutCubic"
          "fadeSwitch, 0, 1, easeOutCirc"
          "fadeDim, 1, 4, fluentDecel"
          "workspaces, 1, 3, easeOutCubic, slide"
          "specialWorkspace, 1, 3, easeOutCubic, slidevert"
          "layers, 1, 4, easeOutQuint"
        ];
      };

      misc = {
        disable_autoreload = true;
        disable_hyprland_logo = true;
        focus_on_activate = false;
        mouse_move_enables_dpms = true;
        key_press_enables_dpms = true;
        background_color = "0xff${colors.base00}";
        new_window_takes_over_fullscreen = 2;
        enable_swallow = false;
        swallow_regex = "^(${desktopCfg.terminal.class})$";
      };

      render = {
        direct_scanout = cfg.directScanout;
        # Fixes stretching artifacts in animations
        # https://github.com/hyprwm/Hyprland/issues/8203
        expand_undersized_textures = false;
      };

      dwindle = {
        preserve_split = true;
        force_split = 2;
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
        ++ (mapAttrsToList (
          name: value:
          "${cfg.namedWorkspaceIDs.${name}}, defaultName:${name}" + optionalString (value != "") ", ${value}"
        ) cfg.namedWorkspaces)
        ++ [
          "special:social, gapsin:${toString (gapSize * 2)}, gapsout:${toString (gapSize * 4)}"
        ];

      # https://github.com/hyprwm/Hyprland/issues/6543
      windowrulev2 = [ "nofocus, class:^$, title:^$, xwayland:1, floating:1, fullscreen:0, pinned:0" ];

      plugin = mkIf cfg.plugins.enable {
        hyprexpo = {
          columns = 3;
          gap_size = 0;
          workspace_method = "first m~1";
          enable_gesture = false;
        };
      };
    };
  };

  darkman.switchApps.hyprland =
    let
      inherit (config.${ns}.colorScheme) colorMap dark;
      hyprctl = getExe' config.wayland.windowManager.hyprland.package "hyprctl";
      mapDarkColor = base: colorMap.${base} // { light = dark.palette.${base}; };
    in
    {
      paths = [ ".config/hypr/hyprland.conf" ];
      # Only reload if gamemode is not active to avoid overriding
      # gamemode-specific hyprland settings
      reloadScript = "${getExe' pkgs.gamemode "gamemoded"} --status | grep 'is active' -q || ${hyprctl} reload";
      colorOverrides = {
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

  systemd.user.services.hyprland-socket-listener = mkIf (cfg.eventScripts != { }) {
    Unit = {
      Description = "Hyprland socket listener";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session-pre.target" ];
    };

    Service = {
      Type = "exec";
      ExecStart = getExe (
        pkgs.writeShellApplication {
          name = "hypr-socket-listener";
          runtimeInputs = [
            hyprlandPkg
            pkgs.socat
          ];
          text =
            # bash
            ''
              ${concatMapStringsSep "\n" (
                event: # bash
                ''
                  ${event}() {
                    IFS=',' read -r -a args <<< "$1"
                    # Strip event<< from the first element
                    args[0]="''${args[0]#*>>}"

                    # Call scripts for this event
                    ${concatMapStringsSep "\n" (script: ''${script} "''${args[@]}"'') cfg.eventScripts.${event}}
                  }
                '') (attrNames cfg.eventScripts)}

              handle() {
                case $1 in
              ${concatMapStringsSep "\n" (event: "    ${event}\\>*) ${event} \"$1\" ;;") (
                attrNames cfg.eventScripts
              )}
                esac
              }

              socat -U - UNIX-CONNECT:"/$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock" \
                | while read -r line; do handle "$line"; done
            '';
        }
      );
    };

    Install.WantedBy = [ "graphical-session.target" ];
  };
}
