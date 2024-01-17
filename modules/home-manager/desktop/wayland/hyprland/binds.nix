{ config
, nixosConfig
, pkgs
, lib
, ...
}:
let
  # TODO: Need to clean this up by moving script and module specific
  # functionality into options
  inherit (lib) optionals optional;
  cfg = config.modules.desktop.hyprland;
  desktopCfg = config.modules.desktop;

  getMonitorByNumber = number: lib.fetchers.getMonitorByNumber nixosConfig number;
  getOption = option: type: "${hyprctl} getoption ${option} -j | ${pkgs.jaq}/bin/jaq -r '.${type}'";

  audio = nixosConfig.modules.system.audio;
  osDesktop = nixosConfig.usrEnv.desktop;

  wpctl = "${pkgs.wireplumber}/bin/wpctl";
  hyprshot = "${pkgs.hyprshot}/bin/hyprshot";
  hyprctl = "${config.wayland.windowManager.hyprland.package}/bin/hyprctl";

  disableShaderCommand =
    let
      shaderDir = "${config.xdg.configHome}/hypr/shaders";
      disableShader = "${hyprctl} keyword decoration:screen_shader ${shaderDir}/blank.frag";
      enableShader = "${hyprctl} keyword decoration:screen_shader ${shaderDir}/monitor1_gamma.frag";
    in
    command: "${disableShader} && ${command} && ${enableShader}";

  toggleFloating = pkgs.writeShellScript "hypr-toggle-floating" ''
    if [[ $(${hyprctl} activewindow -j | ${pkgs.jaq}/bin/jaq -r '.floating') == "false" ]]; then
      ${hyprctl} --batch 'dispatch togglefloating; dispatch resizeactive exact 75% 75%; dispatch centerwindow;'
    else
      ${hyprctl} dispatch togglefloating
    fi
  '';
in
lib.mkIf (osDesktop.enable && desktopCfg.windowManager == "hyprland")
{
  home.packages = [ pkgs.jaq ];

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
          "${mod}, W, killactive,"
          "${mod}, C, exec, ${toggleFloating.outPath}"
          "${mod}, E, fullscreen, 1"
          "${modShift}, E, fullscreen, 0"
          "${mod}, Z, pin, active"
          "${modShift}, R, exec, ${hyprctl} dispatch splitratio exact 1"

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

          # Monitors
          "${modShift}, Comma, movecurrentworkspacetomonitor, ${(getMonitorByNumber 2).name}"
          "${modShift}, Period, movecurrentworkspacetomonitor, ${(getMonitorByNumber 1).name}"
          # TODO: Change this so that it move the cursor in any direction after
          # switching monitors. This is so that when playing games in workspace
          # the cursor doesn't go missing.
          "${mod}, TAB, focusmonitor, +1"

          # Dwindle
          "${mod}, P, pseudo,"
          # TODO: Move this into a script
          "${mod}, M, exec, ${hyprctl} keyword dwindle:no_gaps_when_only $(($(${getOption "dwindle:no_gaps_when_only" "int"}) ^ 1))"
          "${mod}, X, layoutmsg, togglesplit"

          # Hyprshot
          ", Print, exec, ${disableShaderCommand "${hyprshot} -m region --clipboard-only"}"
          "${mod}, I, exec, ${disableShaderCommand "${hyprshot} -m output -m active --clipboard-only"}"
          "${modShift}, Print, exec, ${disableShaderCommand "${hyprshot} -m region"}"
          "${modShift}, I, exec, ${disableShaderCommand "${hyprshot} -m output -m active"}"

          # Workspaces other
          "${mod}, N, workspace, previous"
          "${mod}, S, togglespecialworkspace,"
          "${modShift}, S, movetoworkspacesilent, special"
          "${mod}, G, workspace, name:GAME"
        ] ++ (
          # Workspaces
          let
            workspaceNumbers = lib.lists.map (w: builtins.toString w) (lib.lists.range 1 9);
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
}
