{
  lib,
  cfg,
  pkgs,
  config,
  osConfig,
}:
let
  inherit (lib)
    ns
    mkIf
    optional
    getExe
    getExe'
    replaceStrings
    mkOption
    types
    ;
  inherit (lib.${ns}) mkHyprBind;
  inherit (config.${ns}.programs.desktop) mpv;
  inherit (config.age.secrets) streamlinkTwitchAuth;
  inherit (config.${ns}.desktop) hyprland;
  secondMonitor = lib.${ns}.getMonitorByNumber osConfig 2;
  hyprctl = getExe' pkgs.hyprland "hyprctl";
  twitchWorkspace = hyprland.namedWorkspaceIDs.TWITCH;
  chatterinoPercentage = "17.5";
  firefoxPercentage = "82.5";
  # Horizontal offsets of the chat and the stream as monitor percentages
  chatOffset = if cfg.chatSide == "right" then firefoxPercentage else "0";
  streamOffset = if cfg.chatSide == "right" then "0" else chatterinoPercentage;

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
  opts.chatSide = mkOption {
    type = types.enum [
      "left"
      "right"
    ];
    default = "right";
    description = "Whether to place Chatterino on the left or right of the stream";
  };

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

  ns.desktop = {
    services.waybar.autoHideWorkspaces = [ "TWITCH" ];
    hyprland.namedWorkspaces.TWITCH = {
      monitor = secondMonitor.name;
      on_created_empty = "${hyprctl} repl 'twitch_init_workspace()'";
    };

    hyprland.binds = [
      (mkHyprBind "mod" "T" "hl.dsp.focus({ workspace = ${twitchWorkspace} })")
      (mkHyprBind "mod_shift" "T" "function() twitch_reset_workspace(true) end")
      (mkHyprBind "mod_shift_ctrl" "T" "function() twitch_reset_workspace(false) end")
    ];

    hyprland.extraConf = # lua
      ''
        function twitch_init_workspace()
          -- Check if a special workspace is focused and, if so, close it
          -- (ideally hyprland would close the special workspace if the
          -- workspace that has been switched to is behind it)
          local ws = hl.get_active_special_workspace()
          if ws ~= nil then
            -- strip the leading "special:"
            hl.dispatch(hl.dsp.workspace.toggle_special(ws.name:match(":(.*)") or ws.name))
          end

          -- We can't use the [workspace id silent] exec dispatcher here
          -- because firefox doesn't respect it. Instead we have to assume
          -- that the TWITCH workspace is actively focused.
          hl.exec_cmd("app2unit -t service com.chatterino.chatterino.desktop")
          hl.exec_cmd("app2unit -t service firefox.desktop:new-window https://www.twitch.tv/directory")
        end

        -- Restores the twitch workspace layout. Theater mode places the stream
        -- alongside chat whilst fullscreen mode expands the stream to fill the
        -- monitor and renders the chat overlay on top of it.
        function twitch_reset_workspace(theater)
          local ws = hl.get_workspace(${twitchWorkspace})
          if ws == nil then return end
          local mon = ws.monitor

          local chat_w = ${chatterinoPercentage} / 100
          local chat_x = ${chatOffset} / 100
          local stream_w = ${firefoxPercentage} / 100
          local stream_x = ${streamOffset} / 100

          -- Resize before moving so that the final position is exact
          -- regardless of the anchor the resize uses
          local function place(w, fw, fh, fx)
            local args = { relative = false, window = w }
            hl.dispatch(hl.dsp.window.resize(mon_px(fw, fh, false, args, mon)))
            hl.dispatch(hl.dsp.window.move(mon_px(fx, 0, true, args, mon)))
          end

          local function zorder(w, mode)
            hl.dispatch(hl.dsp.window.alter_zorder({ mode = mode, window = w }))
          end

          for _, w in ipairs(hl.get_workspace_windows(ws)) do
            if w.class == "firefox" or w.class == "mpv" then
              if theater then
                place(w, stream_w, 1, stream_x)
              else
                place(w, 1, 1, 0)
              end
            elseif w.class == "com.chatterino." then
              if w.title:find("Overlay", 1, true) then
                if not theater then place(w, chat_w, 0.4, chat_x) end
                zorder(w, theater and "bottom" or "top")
              else
                place(w, chat_w, 1, chat_x)
                zorder(w, theater and "top" or "bottom")
              end
            else
              zorder(w, "top")
            end
          end
        end
      '';

    hyprland.windowRules = {
      twitch-workspace = {
        match.workspace = twitchWorkspace;
        tag = "+twitch_unexpected";
        float = true;
      };

      twitch-workspace-chatterino-main-window = {
        match = {
          workspace = twitchWorkspace;
          class = "com\\.chatterino\\.";
          title = "Chatterino (${replaceStrings [ "." ] [ "\\." ] pkgs.chatterino7.version} -.*|Overlay)";
        };

        border_size = 0;
        rounding = 0;
        tag = "-twitch_unexpected";
        move = "(monitor_w*${chatOffset}/100) 0";
        size = "(monitor_w*${chatterinoPercentage}/100) monitor_h";
      };

      twitch-workspace-chatterino-usercard = {
        match = {
          workspace = twitchWorkspace;
          class = "com\\.chatterino\\.";
          title = ".* Usercard - .*";
        };

        tag = "-twitch_unexpected";
        size = "(monitor_w*${chatterinoPercentage}/100) monitor_h*0.33";
        center = true;
      };

      twitch-workspace-firefox = {
        match = {
          workspace = twitchWorkspace;
          class = "firefox";
        };

        tag = "-twitch_unexpected";
        border_size = 0;
        rounding = 0;
        move = "(monitor_w*${streamOffset}/100) 0";
        size = "(monitor_w*${firefoxPercentage}/100) monitor_h";
      };

      mpv.match.title = "negative:twitch\\.tv.*";

      twitch-mpv = {
        match = {
          class = "mpv";
          title = "twitch\\.tv.*";
        };

        tag = "-twitch_unexpected";
        border_size = 0;
        rounding = 0;
        workspace = "${twitchWorkspace} silent";
        float = true;
        move = "(monitor_w*${streamOffset}/100) 0";
        size = "(monitor_w*${firefoxPercentage}/100) monitor_h";
      };

      twitch-unexpected = {
        match = {
          workspace = twitchWorkspace;
          tag = "twitch_unexpected*";
        };

        size = "(monitor_w*0.6) (monitor_h*0.6)";
        center = true;
        tag = "-twitch-unexpected";
      };
    };
  };
}
