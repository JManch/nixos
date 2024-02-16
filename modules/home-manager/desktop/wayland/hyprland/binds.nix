{ lib
, pkgs
, config
, vmVariant
, osConfig
, ...
}:
let
  # TODO: Need to clean this up by moving script and module specific
  # functionality into options
  inherit (lib) optionals optional;
  cfg = config.modules.desktop.hyprland;
  desktopCfg = config.modules.desktop;

  getMonitorByNumber = number: lib.fetchers.getMonitorByNumber osConfig number;
  getOption = option: type: "${hyprctl} getoption ${option} -j | ${pkgs.jaq}/bin/jaq -r '.${type}'";

  audio = osConfig.modules.system.audio;
  osDesktop = osConfig.usrEnv.desktop;
  monitors = osConfig.device.monitors;

  wpctl = "${pkgs.wireplumber}/bin/wpctl";
  hyprshot = "${pkgs.hyprshot}/bin/hyprshot";
  hyprctl = "${config.wayland.windowManager.hyprland.package}/bin/hyprctl";

  disableShadersCommand =
    command: "${cfg.disableShaders} && ${command} && ${cfg.enableShaders}";

  toggleFloating = pkgs.writeShellScript "hypr-toggle-floating" ''
    if [[ $(${hyprctl} activewindow -j | ${pkgs.jaq}/bin/jaq -r '.floating') == "false" ]]; then
      ${hyprctl} --batch 'dispatch togglefloating; dispatch resizeactive exact 75% 75%; dispatch centerwindow;'
    else
      ${hyprctl} dispatch togglefloating
    fi
  '';

  toggleSwallowing = pkgs.writeShellScript "hypr-toggle-swallowing" ''
    if [[ $(${hyprctl} getoption -j misc:enable_swallow | ${pkgs.jaq}/bin/jaq -r '.int') == "0" ]]; then
      ${hyprctl} keyword misc:enable_swallow true
      status="enabled"
    else
      ${hyprctl} keyword misc:enable_swallow false
      status="disabled"
    fi
    ${pkgs.libnotify}/bin/notify-send --urgency=low -t 2000 -h 'string:x-canonical-private-synchronous:hypr-swallow' 'Hyprland' "Window swallowing ''$status"
  '';
in
lib.mkIf (osDesktop.enable && desktopCfg.windowManager == "hyprland")
{
  # Force secondaryModKey VM variant because binds are repeated on host
  modules.desktop.hyprland.modKey = lib.mkIf vmVariant (lib.mkVMOverride cfg.secondaryModKey);

  wayland.windowManager.hyprland =
    let
      mod = cfg.modKey;
      modShift = "${cfg.modKey}SHIFT";
      modShiftCtrl = "${cfg.modKey}SHIFTCONTROL";
    in
    {
      settings.bind =
        [
          # General
          "${modShiftCtrl}, Q, exit,"
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
          "${mod}, mouse_up, workspace, r+1"
          "${mod}, mouse_down, workspace, r-1"
          "${mod}, Left, workspace, r-1"
          "${mod}, Right, workspace, r+1"
          "${modShift}, Left, movetoworkspace, r-1"
          "${modShift}, Right, movetoworkspace, r+1"

          # Monitors
          "${modShift}, Comma, movecurrentworkspacetomonitor, ${(getMonitorByNumber 2).name}"
          "${modShift}, Period, movecurrentworkspacetomonitor, ${(getMonitorByNumber 1).name}"
          "${mod}, TAB, focusmonitor, +1"
          "${mod}, TAB, movefocus, u" # Cycle focus to get out of game cursor capture
          "${mod}, TAB, movefocus, d"

          # Dwindle
          "${mod}, P, pseudo,"
          # TODO: Move this into a script
          "${mod}, M, exec, ${hyprctl} keyword dwindle:no_gaps_when_only $(($(${getOption "dwindle:no_gaps_when_only" "int"}) ^ 1))"
          "${mod}, X, layoutmsg, togglesplit"
          "${modShift}, X, layoutmsg, swapsplit"

          # Hyprshot
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
          lib.lists.concatMap
            (m: [
              "${mod}, D, focusmonitor, ${m.name}"
              "${mod}, D, workspace, name:DESKTOP ${toString m.number}"
            ])
            monitors
        ) ++ (
          # Workspaces
          let
            workspaceNumbers = lib.lists.map (w: toString w) (lib.lists.range 1 9);
            workspaceBinds = w: [
              "${mod}, ${w}, workspace, ${w}"
              "${modShift}, ${w}, movetoworkspace, ${w}"
              "${modShiftCtrl}, ${w}, movetoworkspacesilent, ${w}"
            ];
          in
          lib.lists.concatMap workspaceBinds workspaceNumbers
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
        "${modShiftCtrl}, L, resizeactive, 20 0"
        "${modShiftCtrl}, H, resizeactive, -20 0"
        "${modShiftCtrl}, K, resizeactive, 0 -20"
        "${modShiftCtrl}, J, resizeactive, 0 20"
        ", XF86AudioRaiseVolume, exec, ${wpctl} set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+"
        ", XF86AudioLowerVolume, exec, ${wpctl} set-volume @DEFAULT_AUDIO_SINK@ 5%-"
      ];
      extraConfig = ''
        bind = ${mod}, Delete, submap, Grab
        submap = Grab
        bind = ${mod}SHIFT, Delete, submap, reset
        submap = reset
      '';
    };

  programs.zsh.initExtra =
    let
      echo = "${pkgs.coreutils}/bin/echo";
      jaq = "${pkgs.jaq}/bin/jaq";
    in
      /* bash */ ''
      toggle-monitor() {
        if [ -z "$1" ]; then
          ${echo} "Usage: toggle-monitor <monitor_number>"
          return 1
        fi

        declare -A monitorNumToName
        ${builtins.concatStringsSep "\n  "
          (lib.lists.map (m: "monitorNumToName[${toString m.number}]='${m.name}'") monitors)
        }

        declare -A monitorNameToCfg
        ${builtins.concatStringsSep "\n  "
          (lib.lists.map (m: "monitorNameToCfg[${m.name}]='${lib.fetchers.getMonitorHyprlandCfgStr m}'") monitors)
        }

        if [[ ! -v monitorNumToName[$1] ]]; then
          ${echo} "Error: monitor with number '$1' does not exist"
          return 1
        fi

        local monitorName=''${monitorNumToName[$1]}

        # Check if the monitor is already disabled
        ${hyprctl} monitors -j | ${jaq} -e 'first(.[] | select(.name == "'"$monitorName"'"))' > /dev/null 2>&1
        if [ $? -ne 0 ]; then
          disabled=true
        else
          disabled=false
        fi

        if [[ $disabled == true ]]; then
          ${hyprctl} keyword monitor ''${monitorNameToCfg[$monitorName]} > /dev/null
          ${echo} "Enabled monitor $monitorName"
        else
          ${hyprctl} keyword monitor $monitorName,disable > /dev/null
          ${echo} "Disabled monitor $monitorName"
        fi
      }
    '';
}
