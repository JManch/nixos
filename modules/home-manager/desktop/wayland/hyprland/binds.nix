{
  lib,
  pkgs,
  config,
  osConfig,
  vmVariant,
  ...
}@args:
let
  inherit (lib)
    ns
    mkIf
    optionals
    getExe
    getExe'
    flatten
    concatMap
    concatMapStringsSep
    ;
  inherit (lib.${ns}) isHyprland flakePkgs getMonitorHyprlandCfgStr;
  inherit (osConfig.${ns}.system) audio;
  inherit (osConfig.${ns}.device) monitors;
  cfg = desktopCfg.hyprland;
  desktopCfg = config.${ns}.desktop;
  mod = cfg.modKey;
  modShift = "${cfg.modKey}SHIFT";
  modShiftCtrl = "${cfg.modKey}SHIFTCONTROL";

  jaq = getExe pkgs.jaq;
  bc = getExe' pkgs.bc "bc";
  wpctl = getExe' pkgs.wireplumber "wpctl";
  grimblast = getExe (flakePkgs args "grimblast").grimblast;
  notifySend = getExe pkgs.libnotify;
  hyprctl = getExe' pkgs.hyprland "hyprctl";
  loginctl = getExe' pkgs.systemd "loginctl";
  disableShadersCommand = command: "${cfg.disableShaders}; ${command}; ${cfg.enableShaders}";

  toggleDwindleGaps =
    pkgs.writeShellScript "hypr-toggle-dwindle-gaps" # bash
      ''
        new_value=$(($(${hyprctl} getoption -j dwindle:no_gaps_when_only | ${jaq} -r '.int') ^ 1))
        ${hyprctl} keyword dwindle:no_gaps_when_only $new_value
        message=$([[ $new_value == "1" ]] && echo "Dwindle gaps disabled" || echo "Dwindle gaps enabled")
        ${notifySend} --urgency=low -t 2000 -h \
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

  toggleSwallowing =
    pkgs.writeShellScript "hypr-toggle-swallowing" # bash
      ''
        new_value=$(($(${hyprctl} getoption -j misc:enable_swallow | ${jaq} -r '.int') ^ 1))
        ${hyprctl} keyword misc:enable_swallow $new_value
        message=$([[ $new_value == "1" ]] && echo "Window swallowing enabled" || echo "Window swallowing disabled")
        ${notifySend} --urgency=low -t 2000 -h \
          'string:x-canonical-private-synchronous:hypr-swallow' 'Hyprland' "$message"
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
        ${notifySend} --urgency=low -t 2000 -h \
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
        ${notifySend} --urgency=low -t 2000 -h \
          'string:x-canonical-private-synchronous:hypr-scale-tablet' 'Hyprland' 'Scaled tablet to active window'
      '';

  # By design, the wayland clipboard does not sync with unfocused x clients.
  # It's possible to workaround this but constantly syncing the X clipboard but
  # in my experience the workaround is quite buggy and breaks basic clipboard
  # functionality. Since I don't paste into wine applications very frequently,
  # having a bind to manually sync is an acceptable workaround.
  # https://github.com/hyprwm/Hyprland/issues/2319
  syncClipboard =
    pkgs.writeShellScript "sync-clipboard" # bash
      ''
        set -o pipefail
        echo -n "$(${getExe' pkgs.wl-clipboard "wl-paste"} -n)" | ${getExe pkgs.xclip} -selection clipboard && \
          ${notifySend} --urgency=low -t 2000 'Hyprland' 'Synced Wayland clipboard with X11' || \
          ${notifySend} --urgency=critical -t 2000 'Hyprland' 'Clipboard sync failed'
      '';

  copyScreenshotText =
    pkgs.writeShellScript "copy-screenshot-text" # bash
      ''
        set -o pipefail
        ${cfg.disableShaders}
        text=$(${grimblast} --freeze save area - | ${getExe pkgs.tesseract} stdin stdout)
        exit=$?
        ${cfg.enableShaders}
        if [ $exit -eq 0 ]; then
          echo "$text" | ${getExe' pkgs.wl-clipboard "wl-copy"}
          ${notifySend} -t 5000 -a Grimblast "Text Copied" "$text"
        else
          ${notifySend} --urgency=critical -t 5000 "Screenshot" "Failed to copy text"
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

  modifyFocusedWindowVolume = pkgs.writeShellScript "hypr-modify-focused-window-volume" ''
    pid=$(${hyprctl} activewindow -j | ${jaq} -r '.pid')
    node=$(${getExe' pkgs.pipewire "pw-dump"} | ${jaq} -r \
      "[.[] | select((.type == \"PipeWire:Interface:Node\") and (.info?.props?[\"application.process.id\"]? == "$pid"))] | sort_by(if .info?.state? == \"running\" then 0 else 1 end) | first")
    if [ "$node" == "null" ]; then
      ${notifySend} --urgency=critical -t 2000 \
        'Pipewire' "Active window does not have an interface node"
      exit 1
    fi

    id=$(echo "$node" | ${jaq} -r '.id')
    name=$(echo "$node" | ${jaq} -r '.info.props["application.name"]')
    media=$(echo "$node" | ${jaq} -r '.info.props["media.name"]')

    ${wpctl} set-volume "$id" "$1"
    output=$(${wpctl} get-volume "$id")
    volume=''${output#Volume: }
    percentage="$(echo "$volume * 100" | ${bc})"
    ${notifySend} --urgency=low -t 2000 \
      -h 'string:x-canonical-private-synchronous:pipewire-window-volume' "''${name^} - $media" "Volume ''${percentage%.*}%"
  '';
in
mkIf (isHyprland config) {
  # Force secondaryModKey VM variant because binds are repeated on host
  ${ns}.desktop.hyprland.modKey = mkIf vmVariant (lib.mkVMOverride cfg.secondaryModKey);

  wayland.windowManager.hyprland = {
    settings.bind =
      [
        # General
        "${modShiftCtrl}, Q, exec, ${loginctl} terminate-session \"$XDG_SESSION_ID\""
        "${mod}, ${cfg.killActiveKey}, killactive,"
        "${mod}, C, exec, ${toggleFloating}"
        "${mod}, E, exec, ${toggleFullscreen}"
        "${modShift}, E, fullscreen, 0"
        "${mod}, Z, pin, active"
        "${mod}, R, exec, ${hyprctl} dispatch splitratio exact 1"
        "${modShift}, R, exec, ${make16By9}"
        "${mod}, A, exec, ${toggleSwallowing}"
        "${modShift}, T, exec, ${scaleTabletToWindow}"
        "${modShiftCtrl}, T, exec, ${toggleGaps}"
        "${mod}, Space, exec, ${loginctl} lock-session"
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
        "${mod}, mouse_down, workspace, m-1"
        "${mod}, mouse_up, workspace, m+1"
        "${modShift}, Left, movetoworkspace, r-1"
        "${modShift}, Right, movetoworkspace, r+1"
        "${modShift}, J, workspace, m-1"
        "${modShift}, K, workspace, m+1"

        # Monitors
        "${modShift}, H, focusmonitor, l"
        "${modShift}, L, focusmonitor, r"
        "${mod}, TAB, focusmonitor, +1"
        "${modShift}, TAB, movecurrentworkspacetomonitor, +1"

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
        "${mod}, S, togglespecialworkspace, social"
        "${modShift}, S, movetoworkspacesilent, special:social"
      ]
      ++ (concatMap (
        m:
        optionals (m.mirror == null) [
          "${mod}, D, focusmonitor, ${m.name}"
          "${mod}, D, workspace, name:DESKTOP ${toString m.number}"
        ]
      ) monitors)
      ++ (flatten (
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
      ))
      ++ (optionals cfg.plugins.enable [
        "${mod}, Escape, hyprexpo:expo, toggle"
      ])
      ++ (optionals audio.enable [
        ", XF86AudioMute, exec, ${wpctl} set-mute @DEFAULT_AUDIO_SINK@ toggle"
        "${modShift}, XF86AudioRaiseVolume, exec, ${modifyFocusedWindowVolume} 5%+"
        "${modShift}, XF86AudioLowerVolume, exec, ${modifyFocusedWindowVolume} 5%-"
      ]);

    settings.bindm = [
      "${mod}, mouse:272, movewindow"
      "${mod}, mouse:273, resizewindow"
    ];

    settings.bindr = optionals audio.enable [ "${mod}ALT, ALT_L, exec, ${audio.scripts.toggleMic}" ];

    settings.binde =
      optionals audio.enable [
        "${mod}, Right, resizeactive, 20 0"
        "${mod}, Left, resizeactive, -20 0"
        "${mod}, Up, resizeactive, 0 -20"
        "${mod}, Down, resizeactive, 0 20"
      ]
      ++ optionals audio.enable [
        ", XF86AudioRaiseVolume, exec, ${wpctl} set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+"
        ", XF86AudioLowerVolume, exec, ${wpctl} set-volume @DEFAULT_AUDIO_SINK@ 5%-"
      ];

    extraConfig = ''
      bind = ${mod}, Delete, submap, Grab
      submap = Grab
      bind = ${mod}SHIFT, Delete, submap, reset
      submap = reset
    '';
  };

  programs.zsh.initExtra = # bash
    ''
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
