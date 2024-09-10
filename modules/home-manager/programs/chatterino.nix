{
  ns,
  lib,
  pkgs,
  config,
  osConfig',
  ...
}:
let
  inherit (lib)
    mkIf
    optional
    getExe
    ;
  inherit (config.${ns}.programs) mpv;
  inherit (config.age.secrets) streamlinkTwitchAuth;
  inherit (config.home) homeDirectory;
  cfg = config.${ns}.programs.chatterino;
  desktopCfg = config.${ns}.desktop;

  # This is the only way to load the twitch auth secret from agenix
  streamlink = pkgs.streamlink.overrideAttrs (oldAttrs: {
    nativeBuildInputs = oldAttrs.nativeBuildInputs ++ [ pkgs.makeWrapper ];
    postInstall = ''
      wrapProgram $out/bin/streamlink \
        --add-flags "--config ${homeDirectory}/.config/streamlink/config" \
        --add-flags '--config "${streamlinkTwitchAuth.path}"'
    '';
  });

  twitchWorkspaceScript =
    let
      chatterinoRatio = 1.65;
    in
    pkgs.writeShellApplication {
      name = "hypr-twitch-workspace";
      runtimeInputs =
        (with pkgs; [
          coreutils
          chatterino2
          socat
        ])
        ++ [
          config.programs.firefox.finalPackage
          config.wayland.windowManager.hyprland.package
        ];
      text = # bash
        ''
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
                hyprctl dispatch splitratio exact ${toString chatterinoRatio}
              fi
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
              openwindow\>*) open_window "$1" ;;
              createworkspace\>*) create_workspace "$1" ;;
            esac
          }

          socat -U - UNIX-CONNECT:"/$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock" | while read -r line; do handle "$line"; done
        '';
    };
in
mkIf cfg.enable {
  home.packages = [ pkgs.chatterino2 ] ++ optional mpv.enable streamlink;

  programs.mpv.profiles.streamlink = {
    # No point doing fancy scaling on streams
    profile = "fast";

    # Stripped down copy of the low-latency profile that allows playing the
    # stream at custom speeds without lag/audio sync issues
    vd-lavc-threads = 1;
    cache-pause = false;
    demuxer-lavf-o-add = "fflags=+nobuffer";
    demuxer-lavf-analyzeduration = 0.1;
    interpolation = false;
    stream-buffer-size = "4k";

    # Needed for our jump to live keybind
    force-seekable = true;

    # Do not load the modernx osc
    load-scripts = false;
    osc = true;

    # RAM cache to enable rewinding streams
    cache = true;
    demuxer-max-back-bytes = "1024MiB";

    save-position-on-quit = false;
    loop-playlist = "inf";
    loop-file = "inf";
  };

  # WARNING: Enabling the MPV audio compression adds 4 seconds of latency
  xdg.configFile = mkIf mpv.enable {
    "streamlink/config".text = ''
      player=${getExe pkgs.mpv-unwrapped}
      player-args=--profile=streamlink
      twitch-low-latency
      twitch-disable-ads
    '';
  };

  desktop.hyprland.settings =
    let
      secondMonitor = lib.${ns}.getMonitorByNumber osConfig' 2;
    in
    {
      exec-once = [ (getExe twitchWorkspaceScript) ];
      workspace = [
        "name:TWITCH,monitor:${secondMonitor.name}, gapsin:0, gapsout:0, rounding:false, border:false"
      ];
      bind = [ "${desktopCfg.hyprland.modKey}, T, workspace, name:TWITCH" ];
      windowrulev2 = [
        # Not using "name:" here does work however it causes my current workspace
        # to unexpectedly switch so it's needed
        "workspace name:TWITCH, class:mpv, title:^(twitch\.tv.*)$"
      ];
    };

  persistence.directories = [ ".local/share/chatterino/Settings" ];
}
