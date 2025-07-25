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
    optionals
    getExe
    getExe'
    flatten
    concatMapStringsSep
    ;
  inherit (lib.${ns}) flakePkgs getMonitorHyprlandCfgStr;
  inherit (osConfig.${ns}.core.device) monitors backlight;
  mod = cfg.modKey;
  modShift = "${cfg.modKey}SHIFT";
  modShiftCtrl = "${cfg.modKey}SHIFTCONTROL";

  jaq = getExe pkgs.jaq;
  bc = getExe' pkgs.bc "bc";
  awk = getExe pkgs.gawk;
  brightnessctl = getExe pkgs.brightnessctl;
  grimblast = getExe (flakePkgs args "grimblast").grimblast;
  notifySend = getExe pkgs.libnotify;
  hyprctl = getExe' pkgs.hyprland "hyprctl";
  loginctl = getExe' pkgs.systemd "loginctl";
  disableShadersCommand = command: "${cfg.disableShaders} ${command}; ${cfg.enableShaders}";

  toggleDwindleGaps =
    pkgs.writeShellScript "hypr-toggle-dwindle-gaps" # bash
      ''
        new_value=$(($(${hyprctl} getoption -j dwindle:no_gaps_when_only | ${jaq} -r '.int') ^ 1))
        ${hyprctl} keyword dwindle:no_gaps_when_only $new_value
        message=$([[ $new_value == "1" ]] && echo "Dwindle gaps disabled" || echo "Dwindle gaps enabled")
        ${notifySend} -e --urgency=low -t 2000 -h \
          'string:x-canonical-private-synchronous:hypr-dwindle-gaps' 'Hyprland' "$message"
      '';

  toggleFloating =
    pkgs.writeShellScript "hypr-toggle-floating" # bash
      ''
        if [[ $(${hyprctl} activewindow -j | ${jaq} -r '.floating') == "false" ]]; then
          ${hyprctl} --batch 'dispatch togglefloating; dispatch resizeactive exact 75% 75%; dispatch centerwindow;'
        else
          ${hyprctl} dispatch togglefloating
        fi
      '';

  toggleAnimations = pkgs.writeShellScript "hypr-toggle-animations" ''
    if [[ $(${hyprctl} getoption -j animations:enabled | ${jaq} -r '.int') == "1" ]]; then
      hyprctl keyword animations:enabled false
      ${notifySend} -e --urgency=low -t 2000 'Hyprland' 'Animations disabled'
    else
      hyprctl keyword animations:enabled true
      ${notifySend} -e --urgency=low -t 2000 'Hyprland' 'Animations enabled'
    fi
  '';

  toggleAlwaysOnTop =
    pkgs.writeShellScript "hypr-toggle-always-on-top" # bash
      ''
        ${hyprctl} dispatch togglealwaysontop active
        if [ $(${hyprctl} activewindow -j | ${jaq} -r '.alwaysOnTop') = "true" ]; then
          message="enabled"
        else
          message="disabled"
        fi
        ${notifySend} -e --urgency=low -t 2000 -h \
          'string:x-canonical-private-synchronous:hypr-always-on-top' 'Hyprland' "Always on top $message"
      '';

  # Same as `fullscreen, 1` except will not do anything if active workspace
  # contains a single non-fullscreen tiled window
  toggleFullscreen =
    pkgs.writeShellScript "hypr-toggle-fullscreen" # bash
      ''
        active_monitor=$(${hyprctl} monitors -j | ${jaq} -r '.[] | select(.focused == true)')
        id=$(echo "$active_monitor" | ${jaq} -r '.specialWorkspace.id')
        if [ "$id" -ge 0 ]; then
          id=$(echo "$active_monitor" | ${jaq} -r '.activeWorkspace.id')
        fi
        workspace=$(${hyprctl} workspaces -j | ${jaq} -r ".[] | select(.id == $id)")
        windows=$(echo $workspace | ${jaq} -r '.windows')
        hasfullscreen=$(echo $workspace | ${jaq} -r '.hasfullscreen')
        if [[ $windows == 1 && $hasfullscreen == "false" ]]; then
          floating=$(${hyprctl} activewindow -j | ${jaq} -r '.floating')
          if [ $floating = "false" ]; then exit 0; fi
        fi
        ${hyprctl} dispatch fullscreen 1
      '';

  toggleGaps =
    let
      inherit (config.wayland.windowManager.hyprland.settings) general decoration;
    in
    pkgs.writeShellScript "hypr-toggle-gaps" # bash
      ''
        rounding=$(${hyprctl} getoption -j decoration:rounding | ${jaq} -r '.int')
        if [[ "$rounding" == "0" ]]; then
          ${hyprctl} --batch "\
            keyword general:gaps_in ${toString general.gaps_in}; \
            keyword general:gaps_out ${toString general.gaps_out}; \
            keyword general:border_size ${toString general.border_size}; \
            keyword decoration:rounding ${toString decoration.rounding} \
          "
          message="Gaps enabled"
        else
          ${hyprctl} --batch "\
            keyword general:gaps_in 0; \
            keyword general:gaps_out 0; \
            keyword general:border_size 0; \
            keyword decoration:rounding 0 \
          "
          message="Gaps disabled"
        fi
        ${notifySend} -e --urgency=low -t 2000 -h \
          'string:x-canonical-private-synchronous:hypr-toggle-gaps' 'Hyprland' "$message"
      '';

  make16By9 =
    pkgs.writeShellScript "hypr-16-by-9" # bash
      ''
        width=$(${hyprctl} activewindow -j | ${jaq} -r '.size[0]')
        ${hyprctl} dispatch resizeactive exact "$width" "$(( ($width * 9) / 16 ))"
      '';

  scaleTabletToWindow =
    pkgs.writeShellScript "hypr-scale-tablet" # bash
      ''
        tablet_width=152
        tablet_height=95
        window=$(${hyprctl} activewindow -j)
        width=$(echo $window | ${jaq} -r '.size[0]')
        height=$(echo $window | ${jaq} -r '.size[1]')
        pos_x=$(echo $window | ${jaq} -r '.at[0]')
        pos_y=$(echo $window | ${jaq} -r '.at[1]')
        new_width=$(echo "scale=0; $height*$tablet_width/$tablet_height" | ${bc} -l)
        new_height=$(echo "scale=0; $width*$tablet_height/$tablet_width" | ${bc} -l)

        if [ $((width - new_width)) -lt 0 ]; then
            region_height=$new_height
            region_width=$width
            region_pos_x=$pos_x
            region_pos_y=$((pos_y + (height - new_height) / 2))
        else
            region_height=$height
            region_width=$new_width
            region_pos_x=$((pos_x + (width - new_width) / 2))
            region_pos_y=$pos_y
        fi

        ${hyprctl} --batch "\
          keyword input:tablet:region_size $region_width $region_height; \
          keyword input:tablet:output \"\"; \
          keyword input:tablet:absolute_region_position true; \
          keyword input:tablet:region_position $region_pos_x $region_pos_y \
        "
        ${notifySend} -e --urgency=low -t 2000 -h \
          'string:x-canonical-private-synchronous:hypr-scale-tablet' 'Hyprland' 'Scaled tablet to active window'
      '';

  # By design, the wayland clipboard does not sync with unfocused x clients.
  # It's possible to workaround this but constantly syncing the X clipboard but
  # in my experience the workaround is quite buggy and breaks basic clipboard
  # functionality. Since I don't paste into wine applications very frequently,
  # having a bind to manually sync is an acceptable workaround.
  # https://github.com/hyprwm/Hyprland/issues/2319
  syncClipboard =
    pkgs.writeShellScript "hypr-sync-clipboard" # bash
      ''
        set -o pipefail
        echo -n "$(${getExe' pkgs.wl-clipboard "wl-paste"} -n)" | ${getExe pkgs.xclip} -selection clipboard && \
          ${notifySend} -e --urgency=low -t 2000 'Hyprland' 'Synced Wayland clipboard with X11' || \
          ${notifySend} -e --urgency=critical -t 2000 'Hyprland' 'Clipboard sync failed'
      '';

  copyScreenshotText = pkgs.writeShellScript "hypr-copy-screenshot-text" ''
    set -o pipefail
    ${cfg.disableShaders}
    text=$(${grimblast} --freeze save area - | ${getExe pkgs.tesseract} stdin stdout)
    exit=$?
    ${cfg.enableShaders}
    if [ $exit -eq 0 ]; then
      echo "$text" | ${getExe' pkgs.wl-clipboard "wl-copy"}
      ${notifySend} -e -t 5000 -a Grimblast "Text Copied" "$text"
    else
      ${notifySend} -e --urgency=critical -t 5000 "Screenshot" "Failed to copy text"
    fi
  '';

  moveToNextEmpty = pkgs.writeShellScript "hypr-move-to-next-empty" ''
    fullscreen=$(${hyprctl} activewindow -j | ${jaq} -r '.fullscreen')
    cmd="dispatch movetoworkspace emptym"
    if [ "$fullscreen" = 1 ]; then
        cmd+=";dispatch fullscreenstate 0 -1"
    fi
    ${hyprctl} --batch "$cmd"
  '';

  modifyBrightness = pkgs.writeShellScript "hypr-modify-brightness" ''
    ${brightnessctl} set -e4 "$1"
    if [ "$(loginctl show-session $XDG_SESSION_ID -p LockedHint --value)" = "no" ]; then
      brightness=$(${brightnessctl} get --percentage)
      notify-send --urgency=low -t 2000 \
        -h 'string:x-canonical-private-synchronous:brightness' "Display" "Brightness $brightness%"
    fi
  '';

  zoom =
    type:
    pkgs.writeShellScript "hypr-zoom-${type}" ''
      new_zoom=$(${hyprctl} getoption cursor:zoom_factor | ${awk} 'NR==1 {factor = $2; if (factor < 1) {factor = 1}; print factor ${
        if type == "in" then "*" else "/"
      } 1.25}' "$zoom_factor")
      ${hyprctl} keyword cursor:zoom_factor "$new_zoom"
    '';
in
{
  # Force secondaryModKey VM variant because binds are repeated on host
  categoryConfig.modKey = mkIf vmVariant (lib.mkVMOverride cfg.secondaryModKey);

  wayland.windowManager.hyprland = {
    settings.bind = [
      # General
      "${modShiftCtrl}, Q, exec, ${loginctl} terminate-session \"$XDG_SESSION_ID\""
      "${mod}, ${cfg.killActiveKey}, killactive"
      "${mod}, C, exec, ${toggleFloating}"
      "${mod}, E, exec, ${toggleFullscreen}"
      "${modShift}, E, fullscreen, 0"
      "${mod}, Z, exec, ${toggleAlwaysOnTop}"
      "${mod}Shift, Z, pin, active"
      "${mod}, R, exec, ${hyprctl} dispatch splitratio exact 1"
      "${modShift}, R, exec, ${make16By9}"
      "${mod}, A, exec, ${toggleAnimations}"
      "${modShift}, A, exec, ${toggleGaps}"
      "${modShiftCtrl}, V, exec, ${syncClipboard}"

      # Movement
      "${mod}, H, movefocus, l"
      "${mod}, L, movefocus, r"
      "${mod}, K, movefocus, u"
      "${mod}, J, movefocus, d"
      "${modShiftCtrl}, H, movewindow, l"
      "${modShiftCtrl}, L, movewindow, r"
      "${modShiftCtrl}, K, movewindow, u"
      "${modShiftCtrl}, J, movewindow, d"
      "${mod}, mouse:275, workspace, m-1"
      "${mod}, mouse:276, workspace, m+1"
      "${modShift}, Left, movetoworkspace, r-1"
      "${modShift}, Right, movetoworkspace, r+1"
      "${modShift}, J, workspace, m-1"
      "${modShift}, K, workspace, m+1"
      "${mod}, mouse_down, exec, ${zoom "in"}"
      "${mod}, mouse_up, exec, ${zoom "out"}"
      "${modShift}, mouse_up, exec, ${hyprctl} keyword cursor:zoom_factor 1"
      "${mod}, Equal, exec, ${zoom "in"}"
      "${mod}, Minus, exec, ${zoom "out"}"
      "${modShift}, Minus, exec, ${hyprctl} keyword cursor:zoom_factor 1"

      # Monitors
      "${modShift}, H, focusmonitor, l"
      "${modShift}, L, focusmonitor, r"
      "${mod}, TAB, focusmonitor, +1"
      "${modShift}, TAB, movecurrentworkspacetomonitor, +1"
      ", XF86AudioMedia, exec, sleep 1 && hyprctl dispatch dpms toggle"

      # Dwindle
      "${mod}, P, pseudo,"
      "${modShiftCtrl}, G, exec, ${toggleDwindleGaps}"
      "${mod}, X, layoutmsg, togglesplit"
      "${modShift}, X, layoutmsg, swapsplit"

      # Screenshots
      ", Print, exec, ${disableShadersCommand "${grimblast} --notify --freeze copy area"}"
      "${mod}, I, exec, ${disableShadersCommand "${grimblast} --notify copy output"}"
      "${modShift}, Print, exec, ${disableShadersCommand "${grimblast} --notify --freeze save area"}"
      "${modShift}, I, exec, ${disableShadersCommand "${grimblast} --notify save output"}"
      "${modShiftCtrl}, Print, exec, ${disableShadersCommand "${grimblast} --notify --freeze save window"}"
      "${modShiftCtrl}, I, exec, ${disableShadersCommand "${grimblast} --notify --freeze copy window"}"
      "${modShiftCtrl}, C, exec, ${copyScreenshotText}"

      # Workspaces other
      "${mod}, N, workspace, previous_per_monitor"
      "${mod}, M, workspace, emptym"
      "${modShift}, M, exec, ${moveToNextEmpty}"
      "${modShiftCtrl}, M, movetoworkspacesilent, emptym"
    ]
    ++ flatten (
      builtins.genList (
        x:
        let
          key = toString x;
          w = toString (if x == 0 then 10 else x);
        in
        [
          "${mod}, ${key}, workspace, ${w}"
          "${modShift}, ${key}, movetoworkspace, ${w}"
          "${modShiftCtrl}, ${key}, movetoworkspacesilent, ${w}"
        ]
      ) 10
    )
    ++ optionals cfg.plugins [
      "${mod}, Escape, hyprexpo:expo, toggle"
    ];

    settings.bindl = optionals (backlight != null) [
      ", XF86MonBrightnessUp, exec, ${modifyBrightness} 3%+"
      ", XF86MonBrightnessDown, exec, ${modifyBrightness} 3%-"
      "${mod}, XF86MonBrightnessUp, exec, ${modifyBrightness} 1%+"
      "${mod}, XF86MonBrightnessDown, exec, ${modifyBrightness} 1%-"
    ];

    settings.bindm = [
      "${mod}, mouse:272, movewindow"
      "${mod}, mouse:273, resizewindow"
    ];

    settings.binde = [
      "${mod}, Right, resizeactive, 20 0"
      "${mod}, Left, resizeactive, -20 0"
      "${mod}, Up, resizeactive, 0 -20"
      "${mod}, Down, resizeactive, 0 20"
    ];

    extraConfig = ''
      bind = ${mod}, Delete, submap, Grab
      submap = Grab
      bind = ${mod}SHIFT, Delete, submap, reset
      submap = reset
    '';
  };

  programs.zsh.initContent = # bash
    ''
      toggle-dpms() {
        active_monitor=$(hyprctl activeworkspace | jaq -r '.monitor')
        sleep 2 && hyprctl dispatch dpms toggle "$active_monitor"
      }

      toggle-monitor() {
        if [ -z "$1" ]; then
          echo "Usage: toggle-monitor <monitor_number>"
          return 1
        fi

        declare -A monitor_num_to_name
        ${concatMapStringsSep "\n  " (
          m: "monitor_num_to_name[${toString m.number}]='${m.name}'"
        ) monitors}

        declare -A monitor_name_to_cfg
        ${concatMapStringsSep "\n  " (
          m: "monitor_name_to_cfg[${m.name}]='${getMonitorHyprlandCfgStr m}'"
        ) monitors}

        if [[ ! -v monitor_num_to_name[$1] ]]; then
          echo "Error: monitor with number '$1' does not exist"
          return 1
        fi

        local monitor_name=''${monitor_num_to_name[$1]}

        # Check if the monitor is already disabled
        hyprctl monitors all -j | ${jaq} -e 'first(.[] | select((.name == "'"$monitor_name"'") and (.disabled == false)))' > /dev/null 2>&1

        if [ $? -ne 0 ]; then
          hyprctl keyword monitor ''${monitor_name_to_cfg[$monitor_name]} > /dev/null
          echo "Enabled monitor $monitor_name"
          # Some wallpapers programs such as swww do not reload the wallpaper for toggled monitors
          systemctl start --user set-wallpaper
        else
          hyprctl keyword monitor $monitor_name,disable > /dev/null
          echo "Disabled monitor $monitor_name"
        fi
      }
    '';
}
