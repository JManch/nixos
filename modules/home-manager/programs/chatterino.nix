{ lib
, pkgs
, config
, osConfig
, ...
}:
let
  inherit (lib) mkIf optional getExe fetchers;
  inherit (config.modules.programs) mpv;
  cfg = config.modules.programs.chatterino;
  desktopCfg = config.modules.desktop;

  twitchWorkspaceScript =
    let
      chatterinoRatio = 1.65;
    in
    pkgs.writeShellApplication {
      name = "hypr-twitch-workspace";
      runtimeInputs = with pkgs; [
        coreutils
        chatterino2
        socat
        config.programs.firefox.package
        config.wayland.windowManager.hyprland.package
      ];
      text = /*bash*/ ''

        # If a new window is created in the twitch workspace correct the
        # splitratio and move firefox and MPV windows to the left
        open_window() {
          IFS=',' read -r -a args <<< "$1"
          window_address="''${args[0]#*>>}"
          workspace_name="''${args[1]}"
          window_class="''${args[2]}"
          if [[ "$workspace_name" =~ ^(name:|)TWITCH$ ]]; then
            if [[ "$window_class" == "mpv" || "$window_class" == "firefox" ]]; then
              hyprctl --batch "dispatch focuswindow address:0x$window_address; dispatch movewindow l"
              sleep 0.5
            fi
            hyprctl dispatch splitratio exact ${toString chatterinoRatio}
          fi
        }

        # Initialise the twitch workspace with firefox and chatterino
        create_workspace() {
          workspace_name="''${1#*>>}"
          if [[ "$workspace_name" == "TWITCH" ]]; then
            chatterino > /dev/null 2>&1 &
            sleep 0.5
            firefox --new-window twitch.tv/directory > /dev/null 2>&1 &
          fi
        }

        handle() {
          case $1 in
            openwindow*) open_window "$1" ;;
            createworkspace*) create_workspace "$1" ;;
          esac
        }

        socat -U - UNIX-CONNECT:"/tmp/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock" | while read -r line; do handle "$line"; done

      '';
    };
in
mkIf cfg.enable {
  home.packages = with pkgs; [
    chatterino2
  ] ++ optional mpv.enable streamlink;

  xdg.configFile = mkIf mpv.enable {
    "streamlink/config".text = ''
      player=${getExe pkgs.mpv-unwrapped}
      player-args=--load-scripts=no --osc --loop-playlist=inf --loop-file=inf --cache=yes --demuxer-max-back-bytes=1073741824
    '';

    # NOTE: Streamlink config does not include the authentication key. This needs
    # to be manually added as an argument, most commonly in Chatterino
    # TODO: Try using home activation script to insert secret into this file
    "streamlink/config.twitch".text = ''
      twitch-low-latency
      twitch-disable-ads
    '';
  };

  desktop.hyprland.settings =
    let
      secondMonitor = fetchers.getMonitorByNumber osConfig 2;
    in
    {
      exec-once = [ (getExe twitchWorkspaceScript) ];
      workspace = [
        "name:TWITCH,monitor:${secondMonitor.name}, gapsin:0, gapsout:0, rounding:false, border:false}"
      ];
      bind = [ "${desktopCfg.hyprland.modKey}, T, workspace, name:TWITCH" ];
      windowrulev2 = [
        # Not using "name:" here does work however it causes my current workspace
        # to unexpectedly switch so it's needed
        "workspace name:TWITCH, class:mpv, title:^(twitch\.tv.*)$"
      ];
    };

  persistence.directories = [ ".local/share/chatterino" ];
}
