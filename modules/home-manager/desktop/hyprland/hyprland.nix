{
  lib,
  cfg,
  pkgs,
  config,
  osConfig,
  vmVariant,
}:
let
  inherit (lib)
    ns
    mkIf
    mkMerge
    mkVMOverride
    getExe'
    concatMap
    imap
    optionalString
    optionals
    mapAttrsToList
    generators
    concatLines
    mapAttrsRecursive
    mkDefault
    concatMapStringsSep
    ;
  inherit (lib.${ns}) getHyprlandMonitorConfig;
  inherit (config.${ns}.desktop.services) wallpaper;
  inherit (osConfig.${ns}.core) device;
  inherit (desktopCfg.style) gapSize borderWidth;
  toLua = generators.toLua { };
  toLuaInline = generators.toLua { multiline = false; };
  desktopCfg = config.${ns}.desktop;
  colors = config.colorScheme.palette;
  hyprctl = getExe' pkgs.hyprland "hyprctl";

  setupMonitors = pkgs.writeShellApplication {
    name = "setup-monitors";
    runtimeInputs = with pkgs; [
      hyprland
      jaq
    ];
    text = ''
      monitors_json=$(hyprctl monitors all -j)
      monitors=$(echo "$monitors_json" | jaq -r '.[] | .name')
      declare -A selected_monitors=()

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

        count=''${#selected_monitors[@]}
        default_num=$((count + 1))
        read -p "Monitor number (default $default_num): " -r
        [[ -z $REPLY || $REPLY == $'\n' ]] && num="$default_num" || num="$REPLY"

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
          commands+="hl.monitor({ output = \"$monitor\", disabled = true })"$'\n'
        fi
      done
      echo "Commands are $commands"

      # Calculate positions
      pos_x=0
      for monitor in $ordered_monitors; do
        read -r name mode scale <<< "''${selected_monitors["$monitor"]}"
        commands+="hl.monitor({ output = \"$name\", mode = \"$mode\", position = \"''${pos_x}x0\", scale = $scale })"$'\n'
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
          # Creating the workspace rule schedules a prop refresh which updates
          # the persistent property, so the old renameworkspace hack is not needed.
          commands+="hl.workspace_rule({ workspace = $workspace, monitor = \"$name\", persistent = $persistent })"$'\n'
          move_commands+="hl.dispatch(hl.dsp.workspace.move({ workspace = $workspace, monitor = \"$name\" }))"$'\n'
          workspace=$((workspace + monitor_count))
          count=$((count + 1))
        done
      done

      hyprctl eval "$commands" >/dev/null
      sleep 1 # for some reason move commands don't work in the same eval
      hyprctl eval "$move_commands" >/dev/null

      # Wallpapers tend to break if a monitor is toggled or scaling was changed
      ${optionalString wallpaper.enable "systemctl start --user set-wallpaper || true"}
    '';
  };
in
{
  asserts = [
    (!osConfig.xdg.portal.enable)
    "The os xdg portal must be disabled when using Hyprland as it is configured using home-manager"
  ];

  categoryConfig = mkMerge [
    {
      options = mapAttrsRecursive (_: mkDefault) {
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
          accel_profile = "flat";
          sensitivity = 0;

          kb_layout = "us";
          repeat_delay = 200;
          repeat_rate = 30;

          tablet = {
            output = "current";
            transform = 1;
          };

          touchpad = {
            natural_scroll = true;
            scroll_factor = "0.2";
            clickfinger_behavior = true;
            drag_lock = 0;
          };
        };

        cursor = {
          default_monitor = device.primaryMonitor.name;
          inactive_timeout = 0;
          enable_hyprcursor = cfg.hyprcursor.package != null;
          hide_on_key_press = false;
        };

        animations.enabled = true;

        xwayland = {
          # xwayland scaling looks terrible
          force_zero_scaling = true;
        };

        misc = {
          vrr = if cfg.vrr then 1 else 0;
          disable_autoreload = true;
          disable_hyprland_logo = true;
          disable_watchdog_warning = true;
          disable_splash_rendering = true;
          focus_on_activate = false;
          mouse_move_enables_dpms = true;
          # To enable using keybinds when screen has been manually turned off
          # off. Locker script enables this option.
          key_press_enables_dpms = false;
          background_color = "0x000000";
          on_focus_under_fullscreen = 2;
          enable_swallow = false;
          # Otherwise it sometimes appears briefly during shutdown
          lockdead_screen_delay = 10000;
        };

        ecosystem.no_donation_nag = true;

        render = {
          new_render_scheduling = true;
          # We enable direct scanout when gamemode is active. Having it on all
          # the time causes unwanted flickering when switching between fullscreen
          # workspaces.
          direct_scanout = false;
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
      };

      windowRules = {
        # https://github.com/hyprwm/Hyprland/issues/6543
        fix-xwayland-drags = {
          matchers = {
            xwayland = true;
            class = "";
            title = "";
            float = true;
            fullscreen = false;
            pin = false;
          };
          params.no_focus = true;
        };

        no-gaps-when-only = mkIf cfg.noGapsWhenOnly {
          matchers.workspace = "w[tv1]s[false]";
          matchers.float = false;
          params.border_size = 0;
          params.rounding = 0;
        };

        single-window-hide-border = mkIf (!cfg.noGapsWhenOnly) {
          matchers.float = false;
          matchers.workspace = "w[t1]s[false]";
          params.border_size = 0;
        };
      };

      workspaceRules =
        # monitor workspaces
        concatMap (
          m:
          imap (i: w: {
            workspace = w;
            monitor = m.name;
            default = i == 1;
            persistent = i < 3;
          }) m.workspaces
        ) device.monitors

        # named workspaces
        ++ mapAttrsToList (
          name: value:
          {
            workspace = cfg.namedWorkspaceIDs.${name};
            default_name = name;
          }
          // value
        ) cfg.namedWorkspaces

        # special scratch workspaces
        ++ builtins.genList (i: {
          workspace = "special:scratch${toString (i + 1)}";
          gaps_in = gapSize * 2;
          gaps_out = gapSize * 4;
        }) 4

        ++ optionals cfg.noGapsWhenOnly [
          {
            workspace = "w[tv1]s[false]";
            gaps_out = 0;
            gaps_in = 0;
          }
          {
            workspace = "f[1]s[false]";
            gaps_out = 0;
            gaps_in = 0;
          }
        ];
    }

    # Optimise for performance in VM variant
    (mkIf vmVariant (mkVMOverride {
      tearing = false;
      directScanout = false;
      blur = false;
      animations = false;
    }))
  ];

  home.packages = [
    setupMonitors
  ]
  # These are needed for xdg-desktop-portal-hyprland screenshot
  # functionality. Even though I use grimblast the portal may be used in some
  # situations?
  ++ (with pkgs; [
    hyprland
    grim
    slurp
    hyprpicker
  ]);

  # Install Hyprcursor package
  home.file = mkIf (cfg.hyprcursor.package != null) {
    ".icons/${cfg.hyprcursor.name}".source =
      "${cfg.hyprcursor.package}/share/icons/${cfg.hyprcursor.name}";
  };

  xdg.configFile."hypr/hyprland.lua" = {
    text = # lua
      ''
        hl.config(${toLua cfg.options})

        -- window rules
        ${concatLines (
          mapAttrsToList (
            name: v:
            "hl.window_rule(${
              toLuaInline (
                {
                  inherit name;
                  match = v.matchers or { };
                }
                // (v.params or { })
              )
            })"
          ) cfg.windowRules
        )}

        -- monitors
        hl.monitor({
          output = "",
          mode = "preferred",
          position = "auto",
          scale = "auto",
        })

        ${concatLines (map (m: "hl.monitor(${toLuaInline (getHyprlandMonitorConfig m)})") device.monitors)}

        -- workspaces
        ${concatLines (map (w: "hl.workspace_rule(${toLuaInline w})") cfg.workspaceRules)}

        -- animations
        hl.curve("easeInOutQuart", { type = "bezier", points = {{0.76,0},{0.24,1}}})
        hl.curve("fluentDecel", { type = "bezier", points = {{ 0, 0.2}, {0.4, 1}}})
        hl.curve("easeOutCirc", { type = "bezier", points = {{ 0, 0.55},{ 0.45, 1}}})
        hl.curve("easeOutCubic", { type = "bezier", points = {{ 0.33, 1},{ 0.68, 1}}})
        hl.curve("easeinoutsine", { type = "bezier", points = {{ 0.37, 0},{ 0.63, 1}}})
        hl.curve("easeOutQuint", { type = "bezier", points = {{ 0.23, 1},{ 0.32, 1}}})

        hl.animation({ leaf = "windowsIn", enabled = true, speed = 3, bezier = "easeOutCubic", style = "popin 30%"})
        hl.animation({ leaf = "windowsOut", enabled = true, speed = 3, bezier = "fluentDecel", style = "popin 70%"})
        hl.animation({ leaf = "windowsMove", enabled = true, speed = 4, bezier = "easeOutQuint"})
        hl.animation({ leaf = "fadeIn", enabled = true, speed = 3, bezier = "easeOutCubic"})
        hl.animation({ leaf = "fadeOut", enabled = true, speed = 1.7, bezier = "easeOutCubic"})
        hl.animation({ leaf = "fadeSwitch", enabled = false})
        hl.animation({ leaf = "fadeDim", enabled = true, speed = 4, bezier = "fluentDecel"})
        hl.animation({ leaf = "workspaces", speed = 3, bezier = "easeOutCubic", style = "slide", enabled = ${
          if cfg.animations then "true" else "false"
        }})
        hl.animation({ leaf = "specialWorkspace", speed = 3, bezier = "easeOutCubic", style = "slidevert", enabled = ${
          if cfg.animations then "true" else "false"
        }})
        hl.animation({ leaf = "layers", enabled = true, speed = 4, bezier = "easeOutQuint"})

        -- binds
        mod = "${cfg.modKey}"
        mod_shift = mod .. " + SHIFT"
        mod_shift_ctrl = mod .. " + SHIFT + CONTROL"
        ${concatLines cfg.binds}

        -- misc
        local monitors = {
          ${concatMapStringsSep "\n        " (
            m:
            ''[${toString m.number}] = { name = "${m.name}", config = ${toLuaInline (getHyprlandMonitorConfig m)} },''
          ) device.monitors}
        }

        function toggle_monitor(num)
          local m = monitors[num]
          if m == nil then
            return "Error: monitor with number " .. num .. " does not exist"
          end
          if hl.get_monitor(m.name) == nil then
            hl.monitor(m.config)
            ${optionalString wallpaper.enable ''hl.exec_cmd("systemctl start --user set-wallpaper || true")''}
            return "Enabled monitor " .. m.name
          else
            hl.monitor({ output = m.name, disabled = true })
            return "Disabled monitor " .. m.name
          end
        end

        function toggle_dpms()
          local active_monitor = hl.get_active_monitor().name
          hl.timer(function()
            hl.dispatch(hl.dsp.dpms({ action = "toggle", monitor = active_monitor }))
          end, { timeout = 1000, type = "oneshot" })
        end

        ${cfg.extraConf}
      '';
  };

  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-hyprland
      xdg-desktop-portal-gtk
    ];
    configPackages = [ pkgs.hyprland ];
  };

  xdg.configFile."uwsm/env-hyprland".text = ''
    # fix for Java applications in tiling WMs
    export _JAVA_AWT_WM_NONREPARENTING=1
  ''
  + optionalString (cfg.hyprcursor.package != null) ''
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

  ns.desktop.programs.locker = {
    preLockScript = "${hyprctl} keyword misc:key_press_enables_dpms true";
    postUnlockScript = "${hyprctl} keyword misc:key_press_enables_dpms false";
  };

  ns.desktop.darkman.switchScripts.hyprland =
    let
      inherit (config.${ns}.core) color-scheme;
      hyprctl = getExe' pkgs.hyprland "hyprctl";
    in
    theme: ''
      ${hyprctl} eval 'hl.config({
        general = {
          ["col.active_border"]   = "0xff${color-scheme.${theme}.palette.base0D}",
          ["col.inactive_border"] = "0x00${color-scheme.${theme}.palette.base0D}",
        }
      })'
    '';

  programs.zsh = {
    initContent = # bash
      ''
        toggle-monitor() {
          hyprctl repl "toggle_monitor($1)"
        }
      '';

    shellAliases = {
      "hyprland-setup-dev" = "cmake -DCMAKE_EXPORT_COMPILE_COMMANDS=ON -DCMAKE_BUILD_TYPE=Debug -B build";
      "toggle-dpms" = "hyprctl repl 'toggle_dpms()'";
    };
  };

  ns.persistence.directories = [ ".local/share/hyprland" ];
}
