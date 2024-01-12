{ lib
, pkgs
, config
, nixosConfig
, ...
}:
let
  cfg = config.modules.programs.chatterino;
  desktopCfg = config.modules.desktop;
  hyprctl = "${config.wayland.windowManager.hyprland.package}/bin/hyprctl";
  chatterinoRatio = 1.65;
  twitchWorkspaceScript =
    let
      firefox = "${config.programs.firefox.package}/bin/firefox";
      chatterino = "${pkgs.chatterino2}/bin/chatterino";
      socat = "${pkgs.socat}/bin/socat";
    in
    pkgs.writeShellScript "hypr-twitch-workspace" ''
      # If a new window is created in the twitch workspace correct the
      # splitratio and move firefox and MPV windows to the left
      open_window() {
        IFS=',' read -r -a args <<< "$1"
        WINDOW_ADDRESS="''${args[0]#*>>}";
        WORKSPACE_NAME="''${args[1]}";
        WINDOW_CLASS="''${args[2]}";
        if [[ "$WORKSPACE_NAME" =~ ^(name:|)TWITCH$ ]]; then
          if [[ "$WINDOW_CLASS" == "mpv" || "$WINDOW_CLASS" == "firefox" ]]; then
            ${hyprctl} --batch "dispatch focuswindow address:0x$WINDOWADDRESS; dispatch movewindow l"
          fi
          ${hyprctl} dispatch splitratio exact ${builtins.toString chatterinoRatio};
        fi
      }

      # Initialise the twitch workspace with firefox and chatterino
      create_workspace() {
        WORKSPACE_NAME="''${1#*>>}"
        if [[ "$WORKSPACE_NAME" == "TWITCH" ]]; then
          ${chatterino} > /dev/null 2>&1 &
          ${firefox} --new-window twitch.tv > /dev/null 2>&1 &
        fi
      }

      handle() {
        case $1 in
          openwindow*) open_window "$1" ;;
          createworkspace*) create_workspace "$1" ;;
        esac
      }

      ${socat} -U - UNIX-CONNECT:/tmp/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock | while read -r line; do handle "$line"; done
    '';
in
lib.mkIf cfg.enable {
  home.packages = with pkgs; [
    chatterino2
  ];

  impermanence.directories = [
    ".local/share/chatterino"
  ];

  desktop.hyprland.settings = lib.mkIf (desktopCfg.windowManager == "hyprland") {
    exec-once = [
      "${twitchWorkspaceScript.outPath}"
    ];
    workspace = [
      "name:TWITCH,monitor:${(lib.fetchers.getMonitorByNumber nixosConfig 2).name},gapsin:0,gapsout:0,rounding:false,border:false}"
    ];
    bind = [
      "${config.modules.desktop.hyprland.modKey}, T, workspace, name:TWITCH"
    ];
    windowrulev2 = [
      # Not using "name:" here does work however it causes my current workspace
      # to unexpectedly switch so it's needed
      "workspace name:TWITCH,class:mpv,title:^(twitch\.tv.*)$"
    ];
  };
}
