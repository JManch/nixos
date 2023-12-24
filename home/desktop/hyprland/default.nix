{
  config,
  pkgs,
  username,
  ...
}: {
  imports = [
    ./waybar.nix
    ./anyrun.nix
  ];

  home.packages = with pkgs; [
    hyprshot
    swww
    wl-clipboard
    xclip # For xwayland apps
  ];

  wayland.windowManager.hyprland = {
    enable = true;
    # extraConfig = (builtins.readFile ./hyprland.conf);
    settings = let
      monitors = {
        monitor1 = "DP-2";
        monitor2 = "HDMI-A-1";
        monitor3 = "DP-3";
      };

      modKeys = {
        mod = "SUPER";
        modShift = "SUPERSHIFT";
        modShiftCtrl = "SUPERSHIFTCONTROL";
      };
    in {
      # Should inherit these from nvidia really
      env = [
        "XCURSOR_SIZE,24"
        "LIBVA_DRIVER_NAME,nvidia"
        "XDG_SESSION_TYPE,wayland"
        "GBM_BACKEND,nvidia-drm"
        "__GLX_VENDOR_LIBRARY_NAME,nvidia"
        "WLR_NO_HARDWARE_CURSORS,1"
        "NIXOS_OZONE_WL,1"
        "HYPRSHOT_DIR,/home/${username}/pictures/screenshots"
      ];

      # TODO: Modularise this monitor config to be per-host
      monitor = with monitors; [
        ", preferred, auto, 1"
        "${monitor1}, 2560x1440@120, 2560x0, 1"
        "${monitor2}, 2560x1440@59.951, 0x0, 1"
        "${monitor3}, disable"
      ];

      # Launch apps
      exec-once = [
        "hyprctl dispatch focusmonitor ${monitors.monitor1}"
        "sleep 2 && ${pkgs.swww}/bin/swww init"
        # Temporary and buggy fix for fixing pasting into wine applications
        # Can remove xclip package once this is fixed
        # https://github.com/hyprwm/Hyprland/issues/2319
        # https://gitlab.freedesktop.org/wlroots/wlroots/-/merge_requests/4359
        "wl-paste -t text -w sh -c 'v=$(cat); cmp -s <(xclip -selection clipboard -o)  <<< \"$v\" || xclip -selection clipboard <<< \"$v\"'"
      ];

      general = {
        # Borders
        gaps_in = 5;
        gaps_out = 10;
        border_size = 2;
        resize_on_border = true;
        hover_icon_on_border = false;
        "col.active_border" = "0xff${config.colorscheme.colors.base0D}";
        "col.inactive_border" = "0xff${config.colorscheme.colors.base00}";

        # Cursor
        cursor_inactive_timeout = 0;
      };

      decoration = {
        # Edges
        rounding = 10;

        # Blur
        blur = {
          enabled = true;
          size = 2;
          passes = 2;
          xray = true;
        };

        # Shadows
        drop_shadow = false;
        shadow_range = 10;
        shadow_render_power = 2;
        # TODO: Color blue
        # "col.shadow" = $blue;

        screen_shader = "${config.xdg.configHome}/hypr/screenShader.frag";
      };

      input = {
        follow_mouse = 1;
        mouse_refocus = false;

        # Keyboard
        kb_layout = "us";
        repeat_delay = 500;
        repeat_rate = 30;

        # Mouse
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
        # groupbar_titles_font_size = 12
        # groupbar_gradients = false
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

      bind = with modKeys // monitors; let
        firefox = "${config.programs.firefox.package}/bin/firefox";
        alacritty = "${config.programs.alacritty.package}/bin/alacritty";
        hyprshot = "${pkgs.hyprshot}/bin/hyprshot";
        waybar = "${pkgs.waybar}/bin/waybar";
      in [
        # Screenshots
        # ",Print, exec, ${hyprshot} -m region --clipboard-only"
        # "${mod}, Print, exec,${hyprshot} -m region"
        # "${modShift}, Print, exec, ${hyprshot} -m output"
        #
        # "${mod}, Backspace, exec, ${firefox}"
        # "${mod}, Return, exec, ${alacritty}"

        # General
        "${modShift}, Q, exit,"
        ", Print, exec, ${hyprshot} -m region --clipboard-only"
        "${mod}, Print, exec, ${hyprshot} -m region"
        "${modShift}, Print, exec, ${hyprshot} -m output"
        "${mod}, Space, exec, sleep 0.5 && hyprctl dispatch dpms off"
        "${mod}, T, exec, killall -SIGUSR1 ${waybar}"

        # Monitors
        "${mod}, Comma, focusmonitor, ${monitor2}"
        "${mod}, Period, focusmonitor, ${monitor1}"
        "${modShift}, Comma, movecurrentworkspacetomonitor, ${monitor2}"
        "${modShift}, Period, movecurrentworkspacetomonitor, ${monitor1}"

        # Applications
        "${mod}, Backspace, exec, ${firefox}"
        "${mod}, Return, exec, ${alacritty}"

        # Windows
        "${mod}, W, killactive,"
        "${mod}, C, togglefloating,"
        "${mod}, E, fullscreen, 1"
        "${modShift}, E, fullscreen, 0"
        "${mod}, Z, pin, active"

        # Dwindle
        "${mod}, P, pseudo,"
        "${mod}, X, togglesplit,"

        # Groups
        # TODO: Cause of the submap it can't go here to need to move to
        # extraConfig

        # "${mod}, G, togglegroup,"
        # "${modShift}, G, submap, group"
        # "${mod}, B, changegroupactive, f"
        # "submap = group"
        # ", L, moveintogroup, r"
        # ", H, moveintogroup, l"
        # ", K, moveintogroup, u"
        # ", J, moveintogroup, d"
        # "SHIFT, L, moveoutofgroup, r"
        # "SHIFT, H, moveoutofgroup, l"
        # "SHIFT, K, moveoutofgroup, u"
        # "SHIFT, J, moveoutofgroup, d"
        # "bind= , Escape, submap, reset"
        # "submap = reset"

        # Movement
        "${mod}, H, movefocus, l"
        "${mod}, L, movefocus, r"
        "${mod}, K, movefocus, u"
        "${mod}, J, movefocus, d"
        "${modShift}, H, movewindow, l"
        "${modShift}, L, movewindow, r"
        "${modShift}, K, movewindow, u"
        "${modShift}, J, movewindow, d"

        # Resize
        # TODO: Cause of the submap it can't go here to need to move to
        # extraConfig

        # "${mod}, R, submap, resize"
        # "submap = resize"
        # "binde=, L, resizeactive, 20 0"
        # "binde=, H, resizeactive, -20 0"
        # "binde=, K, resizeactive, 0 -20"
        # "binde=, J, resizeactive, 0 20"
        # "bind= , Escape, submap, reset"
        # "submap = reset"

        "${mod}, N, workspace, previous"
        "${mod}, 1, workspace, 1"
        "${mod}, 2, workspace, 2"
        "${mod}, 3, workspace, 3"
        "${mod}, 4, workspace, 4"
        "${mod}, 5, workspace, 5"
        "${mod}, 6, workspace, 6"
        "${mod}, 7, workspace, 7"
        "${mod}, 8, workspace, 8"
        "${mod}, 9, workspace, 9"
        "${modShift}, 1, movetoworkspace, 1"
        "${modShift}, 2, movetoworkspace, 2"
        "${modShift}, 3, movetoworkspace, 3"
        "${modShift}, 4, movetoworkspace, 4"
        "${modShift}, 5, movetoworkspace, 5"
        "${modShift}, 6, movetoworkspace, 6"
        "${modShift}, 7, movetoworkspace, 7"
        "${modShift}, 8, movetoworkspace, 8"
        "${modShift}, 9, movetoworkspace, 9"
        "${modShiftCtrl}, 1, movetoworkspacesilent, 1"
        "${modShiftCtrl}, 2, movetoworkspacesilent, 2"
        "${modShiftCtrl}, 3, movetoworkspacesilent, 3"
        "${modShiftCtrl}, 4, movetoworkspacesilent, 4"
        "${modShiftCtrl}, 5, movetoworkspacesilent, 5"
        "${modShiftCtrl}, 6, movetoworkspacesilent, 6"
        "${modShiftCtrl}, 7, movetoworkspacesilent, 7"
        "${modShiftCtrl}, 8, movetoworkspacesilent, 8"
        "${modShiftCtrl}, 9, movetoworkspacesilent, 9"
        # Special workspace
        "${mod}, S, togglespecialworkspace,"
        "${modShift}, S, movetoworkspacesilent, special"
        # Side mouse buttons
        "${mod}, mouse:275, workspace, m+1"
        "${mod}, mouse:276, workspace, m-1"
        "${mod}, Left, workspace, m+1"
        "${mod}, Right, workspace, m-1"
      ];

      bindr = with modKeys; [
        # TODO: Change bash here to zsh
        # "${mod}, exec, ${pkgs.tofi}/bin/tofi-drun | bash"
      ];

      bindm = with modKeys; [
        # Move/resize windows with mod + LMB/RMB and dragging
        "${mod}, mouse:272, movewindow"
        "${mod}, mouse:273, resizewindow"
      ];

      workspace = with monitors; [
        "1, monitor:${monitor1}, default:true"
        "3, monitor:${monitor1}"
        "5, monitor:${monitor1}"
        "7, monitor:${monitor1}"
        "9, monitor:${monitor1}"
        "2, monitor:${monitor2}, default:true"
        "4, monitor:${monitor2}"
        "6, monitor:${monitor2}"
        "8, monitor:${monitor2}, gapsin:0, gapsout:0, bordersize:0,
        border:false, rounding:false"
      ];
    };
  };

  xdg.configFile."screenShader" = {
    enable = true;
    target = "hypr/screenShader.frag";
    text = ''
      precision mediump float;
      varying vec2 v_texcoord;
      uniform sampler2D tex;
      uniform int output;

      void main() {
          // Apply gamma adjustment to monitor
          if (output == 1) {
              vec4 pixColor = texture2D(tex, v_texcoord);
              pixColor.rgb = pow(pixColor.rgb, vec3(1.2));
              gl_FragColor = pixColor;
          } else {
              gl_FragColor = texture2D(tex, v_texcoord);
          }
      }
    '';
  };
}
