{
  lib,
  cfg,
  args,
  pkgs,
  config,
  osConfig,
  vmVariant,
}:
let
  inherit (lib)
    ns
    mkIf
    mkForce
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
    sliceSuffix
    getMonitorHyprlandCfgStr
    ;
  inherit (osConfig.${ns}.core.device) monitors primaryMonitor;
  inherit (desktopCfg.style) gapSize borderWidth;
  deviceType = osConfig.${ns}.core.device.type;
  desktopCfg = config.${ns}.desktop;
  colors = config.colorScheme.palette;

  setupMonitors = pkgs.writeShellApplication {
    name = "setup-monitors";
    runtimeInputs = with pkgs; [
      hyprland
      jaq
    ];
    text = ''
      monitors_json=$(hyprctl monitors all -j)
      monitors=$(echo "$monitors_json" | jaq -r '.[] | .name')
      declare -A selected_monitors

      for monitor in $monitors; do
        monitor_json=$(echo "$monitors_json" | jaq -r ".[] | select(.name == \"''${monitor}\")")
        name=$(echo "$monitor_json" | jaq -r ".name")
        description=$(echo "$monitor_json" | jaq -r ".description")
        width=$(echo "$monitor_json" | jaq -r ".width")
        height=$(echo "$monitor_json" | jaq -r ".height")
        disabled=$(echo "$monitor_json" | jaq -r ".disabled")
        modes=$(echo "$monitor_json" | jaq -r ".availableModes")

        echo -e "Name: $name\nDesc: $description\nResolution: ''${width}x$height\nDisabled: $disabled\nModes: $modes\n"

        read -p "Use this monitor? (Y/n): " -n 1 -r
        if [[ -n $REPLY ]]; then echo; fi
        if [[ $REPLY =~ ^[Nn]$ ]]; then
          echo -e "\n"
          continue
        fi

        read -p "Monitor number (default $((''${#selected_monitors[@]} + 1))): " -r
        [[ -z $REPLY || $REPLY == $'\n' ]] && num="$((''${#selected_monitors[@]} + 1))" || num="$REPLY"

        max_mode="$(echo "$modes" | jaq -r "first")"
        read -p "Monitor mode (default $max_mode): " -r
        [[ -z $REPLY || $REPLY == $'\n' ]] && mode="$max_mode" || mode="$REPLY"

        read -p "Monitor scale (default 1): " -r
        [[ -z $REPLY || $REPLY == $'\n' ]] && scale=1 || scale="$REPLY"

        selected_monitors["$num"]="$monitor $mode $scale"
        echo -e "\n"
      done

      monitor_count="''${#selected_monitors[@]}"
      if [[ monitor_count -ne 1 ]]; then
        echo -e "Selected monitor numbers: ''${!selected_monitors[*]}"
        expected_sorted_str=$(printf "%s\n" "''${!selected_monitors[@]}" | sort -n | paste -sd ' ')
        while
          read -p "Order the monitor numbers from left to right (e.g. 2 1 3): " -r
          ordered_monitors="$REPLY"
          user_sorted_str=$(echo "$ordered_monitors" | tr -s ' ' '\n' | grep -E '^[0-9]+$' | sort -n | paste -sd ' ')
          [[ $expected_sorted_str != "$user_sorted_str" ]]
        do echo "Please order all monitors"; done
      else
        ordered_monitors=''${!selected_monitors[*]}
      fi

      commands=""

      # Disable monitors not selected
      for monitor in $monitors; do
        echo "Monitor is $monitor."
        selected=false
        for selected_monitor in "''${selected_monitors[@]}"; do
          if [[ $monitor == "$selected_monitor" ]]; then
            selected=true
            break
          fi
        done
        if [[ $selected == false ]]; then
          commands+=";keyword monitor $monitor, disable"
        fi
      done
      echo "Commands are $commands"

      # Calculate positions
      pos_x=0
      for monitor in $ordered_monitors; do
        read -r name mode scale <<< "''${selected_monitors["$monitor"]}"
        commands+=";keyword monitor $name, $mode, ''${pos_x}x0, $scale"
        IFS='x' read -r width _ <<< "$mode"
        echo "width from $mode is $width"
        pos_x=$((pos_x + width))
        echo "new pos_x is $pos_x"
      done

      # Assign workspaces
      move_commands=""
      for monitor in $ordered_monitors; do
        workspace="$monitor"
        count=1
        while ((workspace < 50)); do
          [[ $count -lt 3 ]] && persistent=true || persistent=false
          read -r name _ <<< "''${selected_monitors["$monitor"]}"
          commands+=";keyword workspace $workspace, monitor:$name, persistent:$persistent"
          # needed to update the persistent property of the workspace
          commands+=";dispatch renameworkspace $workspace $workspace"
          move_commands+=";dispatch moveworkspacetomonitor $workspace $name"
          workspace=$((workspace + monitor_count))
          count=$((count + 1))
        done
      done

      hyprctl --batch "$commands"
      sleep 1 # for some reason move commands don't work in the same batch command
      hyprctl --batch "$move_commands" >/dev/null
    '';
  };
in
{
  asserts = [
    (!osConfig.xdg.portal.enable)
    "The os xdg portal must be disabled when using Hyprland as it is configured using home-manager"
  ];

  # Optimise for performance in VM variant
  categoryConfig = mkIf vmVariant (mkVMOverride {
    tearing = false;
    directScanout = false;
    blur = false;
    animations = false;
  });

  home.packages =
    [
      setupMonitors
      (flakePkgs args "grimblast").grimblast
    ]
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
    ".icons/${cfg.hyprcursor.name}".source =
      "${cfg.hyprcursor.package}/share/icons/${cfg.hyprcursor.name}";
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
    enable = mkForce true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-hyprland
      xdg-desktop-portal-gtk
    ];
    configPackages = [ pkgs.hyprland ];
  };

  xdg.configFile."uwsm/env-hyprland".text =
    optionalString (cfg.hyprcursor.package != null) ''
      export HYPRCURSOR_THEME=${cfg.hyprcursor.name}
      export HYPRCURSOR_SIZE=${toString config.${ns}.desktop.style.cursor.size}
    ''
    + optionalString (osConfig.${ns}.core.device.gpu.type == "nvidia") ''
      export LIBVA_DRIVER_NAME=nvidia
      export GBM_BACKEND=nvidia-drm
      export __GLX_VENDOR_LIBRARY_NAME=nvidia
      export __GL_GSYNC_ALLOWED=0
      export __GL_VRR_ALLOWED=0
    '';

  wayland.windowManager.hyprland = {
    enable = true;
    systemd.enable = false; # we use UWSM instead
    plugins = optionals cfg.plugins (with flakePkgs args "hyprland-plugins"; [ hyprexpo ]);
    package = null;
    portalPackage = null; # we configure the portal ourselves above

    settings = {
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
        "col.inactive_border" = "0x00${colors.base0D}";
        allow_tearing = cfg.tearing;
      };

      decoration = {
        rounding = desktopCfg.style.cornerRadius - 2;
        rounding_power = 4;
        shadow.enabled = false;

        blur = {
          enabled = cfg.blur;
          size = 2;
          passes = 3;
          xray = false;
          special = true;
        };
      };

      input = {
        follow_mouse = 1;
        mouse_refocus = true;
        accel_profile = mkIf (deviceType != "laptop") "flat";
        sensitivity = 0;

        kb_layout = "us";
        repeat_delay = 500;
        repeat_rate = 30;

        tablet = {
          output = "current";
          transform = 1;
        };

        touchpad = {
          natural_scroll = true;
          scroll_factor = 0.6;
          clickfinger_behavior = true;
        };
      };

      gestures.workspace_swipe = true;

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

      xwayland = {
        # xwayland scaling looks terrible
        force_zero_scaling = true;
      };

      misc = {
        vrr = if cfg.vrr then 1 else 0;
        disable_autoreload = true;
        disable_hyprland_logo = true;
        focus_on_activate = false;
        mouse_move_enables_dpms = true;
        key_press_enables_dpms = true;
        background_color = "0x000000";
        new_window_takes_over_fullscreen = 2;
        enable_swallow = false;
        # Otherwise it sometimes appears briefly during shutdown
        lockdead_screen_delay = 10000;
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
        ) cfg.namedWorkspaces);

      windowrule = [
        # https://github.com/hyprwm/Hyprland/issues/6543
        "nofocus, class:^$, title:^$, xwayland:1, floating:1, fullscreen:0, pinned:0"
        # Hide window border when there's only 1 window in a non-special
        # workspace or the window is fullscreen
        "noborder, onworkspace:w[t1]s[false]"
        "noborder, onworkspace:f[1]"
      ];

      plugin = mkIf cfg.plugins {
        hyprexpo = {
          columns = 3;
          gap_size = 0;
          workspace_method = "first m~1";
          enable_gesture = false;
        };
      };
    };
  };

  ns.desktop.darkman.switchApps.hyprland =
    let
      inherit (config.${ns}.core.color-scheme) colorMap dark;
      hyprctl = getExe' pkgs.hyprland "hyprctl";
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
      After = [ "graphical-session.target" ];
    };

    Service = {
      Type = "exec";
      Slice = "background${sliceSuffix osConfig}.slice";
      Restart = "always";
      RestartSec = 30;
      ExecStart = getExe (
        pkgs.writeShellApplication {
          name = "hypr-socket-listener";
          runtimeInputs = with pkgs; [
            hyprland
            socat
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

  ns.persistence.directories = [ ".local/share/hyprland" ];
}
