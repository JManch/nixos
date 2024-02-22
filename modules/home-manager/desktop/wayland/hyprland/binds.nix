{ lib
, pkgs
, config
, osConfig
, vmVariant
, ...
}:
let
  inherit (lib)
    mkIf
    optionals
    optional
    getExe
    getExe'
    range
    concatMap
    fetchers
    concatStringsSep;
  inherit (osConfig.modules.system) audio;
  inherit (osConfig.device) monitors;
  cfg = desktopCfg.hyprland;
  desktopCfg = config.modules.desktop;
  osDesktop = osConfig.usrEnv.desktop;

  jaq = getExe pkgs.jaq;
  notifySend = getExe pkgs.libnotify;
  hyprctl = getExe' config.wayland.windowManager.hyprland.package "hyprctl";

  getMonitorByNumber = number: fetchers.getMonitorByNumber osConfig number;

  disableShadersCommand =
    command: "${cfg.disableShaders} && ${command} && ${cfg.enableShaders}";

  toggleDwindleGaps = pkgs.writeShellScript "hypr-toggle-dwindle-gaps" /*bash*/ ''

    new_value=$(($(${hyprctl} getoption -j dwindle:no_gaps_when_only | ${jaq} -r '.int') ^ 1))
    ${hyprctl} keyword dwindle:no_gaps_when_only $new_value
    message=$([[ $new_value == "1" ]] && echo "Dwindle gaps disabled" || echo "Dwindle gaps enabled")
    ${notifySend} --urgency=low -t 2000 -h \
      'string:x-canonical-private-synchronous:hypr-dwindle-gaps' 'Hyprland' "$message"

  '';

  toggleFloating = pkgs.writeShellScript "hypr-toggle-floating" /*bash*/ ''

    if [[ $(${hyprctl} activewindow -j | ${jaq} -r '.floating') == "false" ]]; then
      ${hyprctl} --batch 'dispatch togglefloating; dispatch resizeactive exact 75% 75%; dispatch centerwindow;'
    else
      ${hyprctl} dispatch togglefloating
    fi

  '';

  toggleSwallowing = pkgs.writeShellScript "hypr-toggle-swallowing" /*bash*/ ''

    new_value=$(($(${hyprctl} getoption -j misc:enable_swallow | ${jaq} -r '.int') ^ 1))
    ${hyprctl} keyword misc:enable_swallow $new_value
    message=$([[ $new_value == "1" ]] && echo "Window swallowing enabled" || echo "Window swallowing disabled")
    ${notifySend} --urgency=low -t 2000 -h \
      'string:x-canonical-private-synchronous:hypr-swallow' 'Hyprland' "$message"

  '';

  # Temporary workaround for https://github.com/hyprwm/Hyprland/issues/3558
  killHyprland =
    let
      pgrep = getExe' pkgs.procps "pgrep";
      sleep = getExe' pkgs.coreutils "sleep";
      killall = getExe pkgs.killall;
    in
    pkgs.writeShellScript "hypr-kill" /*bash*/ ''

    if ${pgrep} -x Hyprland > /dev/null; then
      ${hyprctl} dispatch exit 0
      ${sleep} 5
      if ${pgrep} -x Hyprland > /dev/null; then
        ${killall} -9 Hyprland
      fi
    fi

  '';
in
mkIf (osDesktop.enable && desktopCfg.windowManager == "Hyprland")
{
  # Force secondaryModKey VM variant because binds are repeated on host
  modules.desktop.hyprland.modKey = mkIf vmVariant (lib.mkVMOverride cfg.secondaryModKey);

  wayland.windowManager.hyprland =
    let
      mod = cfg.modKey;
      modShift = "${cfg.modKey}SHIFT";
      modShiftCtrl = "${cfg.modKey}SHIFTCONTROL";

      hyprshot = getExe pkgs.hyprshot;
      wpctl = getExe' pkgs.wireplumber "wpctl";
    in
    {
      settings.bind =
        [
          # General
          "${modShiftCtrl}, Q, exec, ${killHyprland.outPath}"
          "${mod}, ${cfg.killActiveKey}, killactive,"
          "${mod}, C, exec, ${toggleFloating.outPath}"
          "${mod}, E, fullscreen, 1"
          "${modShift}, E, fullscreen, 0"
          "${mod}, Z, pin, active"
          "${mod}, R, exec, ${hyprctl} dispatch splitratio exact 1"
          "${mod}, A, exec, ${toggleSwallowing.outPath}"

          # Movement
          "${mod}, H, movefocus, l"
          "${mod}, L, movefocus, r"
          "${mod}, K, movefocus, u"
          "${mod}, J, movefocus, d"
          "${modShift}, H, movewindow, l"
          "${modShift}, L, movewindow, r"
          "${modShift}, K, movewindow, u"
          "${modShift}, J, movewindow, d"
          "${mod}, mouse:276, workspace, r-1"
          "${mod}, mouse:275, workspace, r+1"
          "${modShift}, Left, movetoworkspace, r-1"
          "${modShift}, Right, movetoworkspace, r+1"
          "${modShiftCtrl}, J, workspace, r-1"
          "${modShiftCtrl}, K, workspace, r+1"

          # Monitors
          "${modShift}, Comma, movecurrentworkspacetomonitor, ${(getMonitorByNumber 2).name}"
          "${modShift}, Period, movecurrentworkspacetomonitor, ${(getMonitorByNumber 1).name}"
          "${modShiftCtrl}, H, focusmonitor, l"
          "${modShiftCtrl}, L, focusmonitor, r"
          "${mod}, TAB, focusmonitor, +1"

          # Dwindle
          "${mod}, P, pseudo,"
          "${mod}, M, exec, ${toggleDwindleGaps.outPath}"
          "${mod}, X, layoutmsg, togglesplit"
          "${modShift}, X, layoutmsg, swapsplit"

          # Screenshots
          ", Print, exec, ${disableShadersCommand "${hyprshot} -m region --clipboard-only"}"
          "${mod}, I, exec, ${disableShadersCommand "${hyprshot} -m output -m active --clipboard-only"}"
          "${modShift}, Print, exec, ${disableShadersCommand "${hyprshot} -m region"}"
          "${modShift}, I, exec, ${disableShadersCommand "${hyprshot} -m output -m active"}"

          # Workspaces other
          "${mod}, N, workspace, previous"
          "${mod}, S, togglespecialworkspace,"
          "${modShift}, S, movetoworkspacesilent, special"
          "${mod}, G, workspace, name:GAME"
          "${mod}, V, workspace, name:VM"
        ] ++ (
          # Go to empty workspace on all monitors
          concatMap
            (m: [
              "${mod}, D, focusmonitor, ${m.name}"
              "${mod}, D, workspace, name:DESKTOP ${toString m.number}"
            ])
            monitors
        ) ++ (
          # Workspaces
          let
            workspaceNumbers = map (w: toString w) (range 1 9);
            workspaceBinds = w: [
              "${mod}, ${w}, workspace, ${w}"
              "${modShift}, ${w}, movetoworkspace, ${w}"
              "${modShiftCtrl}, ${w}, movetoworkspacesilent, ${w}"
            ];
          in
          concatMap workspaceBinds workspaceNumbers
        ) ++ (optional audio.enable (
          ", XF86AudioMute, exec, ${wpctl} set-mute @DEFAULT_AUDIO_SINK@ toggle"
        ));

      settings.bindm = [
        # Mouse window interaction
        "${mod}, mouse:272, movewindow"
        "${mod}, mouse:273, resizewindow"
      ];

      settings.bindr = optionals audio.enable [
        "${mod}ALT, ALT_L, exec, ${audio.scripts.toggleMic}"
      ];

      settings.binde = optionals audio.enable [
        "${mod}, Right, resizeactive, 20 0"
        "${mod}, Left, resizeactive, -20 0"
        "${mod}, Up, resizeactive, 0 -20"
        "${mod}, Down, resizeactive, 0 20"
      ] ++ optionals audio.enable [
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

  programs.zsh.initExtra = /*bash*/ ''

    toggle-monitor() {
      if [ -z "$1" ]; then
        echo "Usage: toggle-monitor <monitor_number>"
        return 1
      fi

      declare -A monitor_num_to_name
      ${concatStringsSep "\n  "
        (map (m: "monitor_num_to_name[${toString m.number}]='${m.name}'") monitors)
      }

      declare -A monitor_name_to_cfg
      ${concatStringsSep "\n  "
        (map (m: "monitor_name_to_cfg[${m.name}]='${fetchers.getMonitorHyprlandCfgStr m}'") monitors)
      }

      if [[ ! -v monitor_num_to_name[$1] ]]; then
        echo "Error: monitor with number '$1' does not exist"
        return 1
      fi

      local monitor_name=''${monitor_num_to_name[$1]}

      # Check if the monitor is already disabled
      ${hyprctl} monitors -j | ${jaq} -e 'first(.[] | select(.name == "'"$monitor_name"'"))' > /dev/null 2>&1

      if [ $? -ne 0 ]; then
        ${hyprctl} keyword monitor ''${monitor_name_to_cfg[$monitor_name]} > /dev/null
        echo "Enabled monitor $monitor_name"
      else
        ${hyprctl} keyword monitor $monitor_name,disable > /dev/null
        echo "Disabled monitor $monitor_name"
      fi
    }

  '';
}
