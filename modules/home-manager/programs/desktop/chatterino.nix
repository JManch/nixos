{
  lib,
  pkgs,
  config,
  osConfig,
}:
let
  inherit (lib)
    ns
    mkIf
    optional
    optionalString
    getExe
    replaceStrings
    ;
  inherit (config.${ns}.programs.desktop) mpv;
  inherit (config.age.secrets) streamlinkTwitchAuth;
  inherit (config.${ns}.desktop) hyprland;
  inherit (osConfig.${ns}.system.desktop.hyprland) alwaysOnTopPatch;
  secondMonitor = lib.${ns}.getMonitorByNumber osConfig 2;
  chatterinoPercentage = "17.5";
  firefoxPercentage = "82.5";

  # Wrap with twitch auth token config
  streamlink = pkgs.symlinkJoin {
    name = "streamlink-wrapped";
    paths = [ pkgs.streamlink ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/streamlink \
        --add-flags '--config "${config.xdg.configHome}/streamlink/config"' \
        --add-flags '--config "${streamlinkTwitchAuth.path}"'
    '';
  };
in
{
  home.packages = [ pkgs.chatterino7 ] ++ optional mpv.enable streamlink;

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

  ns.backups.chatterino = {
    backend = "restic";
    paths = [ ".local/share/chatterino/Settings" ];
  };

  ns.persistence.directories = [ ".local/share/chatterino/Settings" ];

  programs.waybar.settings.bar = mkIf (lib.${ns}.isHyprland config) {
    "hyprland/workspaces".format-icons.TWITCH = "󰕃";
  };

  ns.desktop =
    let
      initWorkspace = pkgs.writeShellApplication {
        name = "hypr-chatterino-init-workspace";
        runtimeInputs = [
          pkgs.hyprland
          pkgs.jaq
          pkgs.app2unit
        ];
        text = ''
          # Check if a special workspace is focused and, if so, close it
          # (ideally hyprland would close the special workspace if the
          # workspace that has been switched to is behind it)
          specialworkspace=$(hyprctl monitors -j | jaq -r '.[] | select(.focused == true) | .specialWorkspace')
          id=$(echo "$specialworkspace" | jaq -r '.id')
          if [ "$id" -lt 0 ]; then
            name=$(echo "$specialworkspace" | jaq -r '.name')
            hyprctl dispatch togglespecialworkspace "''${name#special:}"
          fi

          # We can't use the [workspace id silent] exec dispatcher here
          # because firefox doesn't respect it. Instead we have to assume
          # that the TWITCH workspace is actively focused.
          app2unit -t service com.chatterino.chatterino.desktop
          app2unit -t service firefox.desktop:new-window https://www.twitch.tv/directory
        '';
      };

      resetWorkspace =
        theaterMode:
        pkgs.writeShellApplication {
          name = "hypr-chatterino-reset-${if theaterMode then "theater" else "fullscreen"}-workspace";
          runtimeInputs = [
            pkgs.hyprland
            pkgs.jaq
          ];
          text = ''
            cmds=""
            windows=$(hyprctl clients -j | jaq -r '((.[] | select(.workspace.name == "TWITCH")) | "\(.address),\(.class),\(.title),\(.alwaysOnTop)")')
            while IFS=',' read -r address class title alwaysontop; do
              if [ "$class" = "firefox" ] || [ "$class" = "mpv" ]; then
                cmds+="dispatch movewindowpixel exact 0% 0%, address:$address;"
                cmds+="dispatch resizewindowpixel exact ${
                  if theaterMode then firefoxPercentage else "100"
                }% 100%, address:$address;"
              elif [ "$class" = "com.chatterino." ]; then
                if [[ "$title" == *"Overlay"* ]]; then
                  ${optionalString (!theaterMode) ''
                    cmds+="dispatch resizewindowpixel exact ${chatterinoPercentage}% 40%, address:$address;"
                    cmds+="dispatch movewindowpixel exact ${firefoxPercentage}% 0%, address:$address;"
                  ''}
                  if [ "$alwaysontop" = "${if theaterMode then "true" else "false"}" ]; then
                    cmds+="dispatch togglealwaysontop address:$address;"
                  fi
                  cmds+="dispatch alterzorder ${if theaterMode then "bottom" else "top"}, address:$address;"
                else
                  cmds+="dispatch resizewindowpixel exact ${chatterinoPercentage}% 100%, address:$address;"
                  cmds+="dispatch movewindowpixel exact ${firefoxPercentage}% 0%, address:$address;"
                  cmds+="dispatch alterzorder ${if theaterMode then "top" else "bottom"}, address:$address;"
                fi
              else
                cmds+="dispatch alterzorder top, address:$address;"
              fi
            done <<< "$windows"
            hyprctl dispatch --batch "$cmds"
          '';
        };
    in
    {
      services.waybar.autoHideWorkspaces = [ "TWITCH" ];
      hyprland.namedWorkspaces.TWITCH = "monitor:${secondMonitor.name}, on-created-empty:${getExe initWorkspace}";

      hyprland.settings = {
        bind = [
          "${hyprland.modKey}, T, workspace, ${hyprland.namedWorkspaceIDs.TWITCH}"
          "${hyprland.modKey}SHIFT, T, exec, ${getExe (resetWorkspace true)}"
          "${hyprland.modKey}SHIFTCONTROL, T, exec, ${getExe (resetWorkspace false)}"
        ];
      };

      hyprland.windowRules = {
        twitch-workspace = {
          matchers.workspace = hyprland.namedWorkspaceIDs.TWITCH;
          params = {
            tag = "+twitch_unexpected";
            float = true;
          };
        };

        twitch-workspace-chatterino-main-window = {
          matchers = {
            workspace = hyprland.namedWorkspaceIDs.TWITCH;
            class = "com\\.chatterino\\.";
            title = "Chatterino (${replaceStrings [ "." ] [ "\\." ] pkgs.chatterino7.version} -.*|Overlay)";
          };

          params = {
            border_size = 0;
            rounding = 0;
            tag = "-twitch_unexpected";
            move = "(monitor_w*${firefoxPercentage}/100) 0";
            size = "(monitor_w*${chatterinoPercentage}/100) monitor_h";
          };
        };

        twitch-workspace-chatterino-usercard = {
          matchers = {
            workspace = hyprland.namedWorkspaceIDs.TWITCH;
            class = "com\\.chatterino\\.";
            title = ".* Usercard - .*";
          };

          params = {
            tag = "-twitch_unexpected";
            always_on_top = mkIf alwaysOnTopPatch true;
            size = "(monitor_w*${chatterinoPercentage}/100) monitor_h*0.33";
            center = true;
          };
        };

        twitch-workspace-firefox = {
          matchers = {
            workspace = hyprland.namedWorkspaceIDs.TWITCH;
            class = "firefox";
          };

          params = {
            tag = "-twitch_unexpected";
            border_size = 0;
            rounding = 0;
            move = "0 0";
            size = "(monitor_w*${firefoxPercentage}/100) monitor_h";
          };
        };

        mpv.matchers.title = "negative:twitch\\.tv.*";

        twitch-mpv = {
          matchers = {
            class = "mpv";
            title = "twitch\\.tv.*";
          };

          params = {
            tag = "-twitch_unexpected";
            border_size = 0;
            rounding = 0;
            workspace = "${hyprland.namedWorkspaceIDs.TWITCH} silent";
            float = true;
            move = "0 0";
            size = "(monitor_w*${firefoxPercentage}/100) monitor_h";
          };
        };

        twitch-unexpected = {
          matchers = {
            workspace = hyprland.namedWorkspaceIDs.TWITCH;
            tag = "twitch_unexpected*";
          };

          params = {
            always_on_top = mkIf alwaysOnTopPatch true;
            size = "(monitor_w*0.6) (monitor_h*0.6)";
            center = true;
            tag = "-twitch-unexpected";
          };
        };
      };
    };
}
