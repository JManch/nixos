{
  lib,
  pkgs,
  config,
  osConfig',
  ...
}:
let
  inherit (lib)
    ns
    mkIf
    optional
    getExe
    ;
  inherit (config.${ns}.programs) mpv;
  inherit (config.age.secrets) streamlinkTwitchAuth;
  inherit (config.home) homeDirectory;
  inherit (config.${ns}.desktop.hyprland) namedWorkspaceIDs;
  cfg = config.${ns}.programs.chatterino;
  desktopCfg = config.${ns}.desktop;
  secondMonitor = lib.${ns}.getMonitorByNumber osConfig' 2;
  chatterinoPercentage = 17.5;

  # Wrap with twitch auth token config
  streamlinkPkg = pkgs.symlinkJoin {
    name = "streamlink-wrapped";
    paths = [ pkgs.streamlink ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/streamlink \
        --add-flags '--config ${homeDirectory}/.config/streamlink/config' \
        --add-flags '--config "${streamlinkTwitchAuth.path}"'
    '';
  };
in
mkIf cfg.enable {
  home.packages = [ pkgs.chatterino2 ] ++ optional mpv.enable streamlinkPkg;

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

  ${ns}.desktop = {
    services.waybar.autoHideWorkspaces = [ "TWITCH" ];
    hyprland.namedWorkspaces.TWITCH = "monitor:${secondMonitor.name}, decorate:false, rounding:false, border:false, gapsin:0, gapsout:0";
  };

  desktop.hyprland.settings = {
    bind = [ "${desktopCfg.hyprland.modKey}, T, workspace, ${namedWorkspaceIDs.TWITCH}" ];
    workspace = [
      "${namedWorkspaceIDs.TWITCH}, on-created-empty:${pkgs.writeShellScript "hypr-chatterino-create-workspace" ''
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
        app2unit chatterino &
        app2unit -- firefox --new-window twitch.tv/directory
      ''}"
    ];
    windowrulev2 =
      let
        workspaceMatch = "workspace:${namedWorkspaceIDs.TWITCH}";
      in
      [
        # Rules for chatterino window on twitch workspace
        "float, ${workspaceMatch}, class:^(com\\.chatterino\\.)$"
        "move ${
          toString (100 - chatterinoPercentage)
        }% 0%, ${workspaceMatch}, class:^(com\\.chatterino\\.)$"
        "size ${toString chatterinoPercentage}% 100%, ${workspaceMatch}, class:^(com\\.chatterino\\.)$"

        # Rules for firefox window opened on twitch workspace
        "float, ${workspaceMatch}, class:^(firefox)$"
        "move 0% 0%, ${workspaceMatch}, class:^(firefox)$"
        "size ${toString (100 - chatterinoPercentage)}% 100%, ${workspaceMatch}, class:^(firefox)$"

        # Rules for mpv twitch streams opened on twitch workspace or other workspaces
        "workspace ${namedWorkspaceIDs.TWITCH} silent, class:^(mpv)$, title:^(twitch\\.tv.*)$"
        "float, class:^(mpv)$, title:^(twitch\\.tv.*)$"
        "move 0% 0%, class:^(mpv)$, title:^(twitch\\.tv.*)$"
        "size ${toString (100 - chatterinoPercentage)}% 100%, class:^(mpv)$, title:^(twitch\\.tv.*)$"
      ];
  };

  persistence.directories = [ ".local/share/chatterino/Settings" ];
}
