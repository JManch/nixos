{ lib
, pkgs
, config
, hostname
, osConfig'
, isWayland
, desktopEnabled
, ...
}:
let
  inherit (lib)
    utils
    mkIf
    optional
    getExe'
    toUpper
    mkForce
    getExe
    filter
    escapeShellArg
    imap1
    sort
    concatLines;
  inherit (config.modules.desktop.services) hypridle;
  inherit (osConfig'.device) gpu;
  cfg = desktopCfg.services.waybar;
  desktopCfg = config.modules.desktop;
  isHyprland = desktopCfg.windowManager == "hyprland";
  colors = config.colorScheme.palette;

  audio = osConfig'.modules.system.audio;
  wgnord = osConfig'.modules.services.wgnord;
  gamemode = osConfig'.modules.programs.gaming.gamemode;
  gpuModuleEnabled = (gpu.type == "amd") && (gpu.hwmonId != null);
  systemctl = getExe' pkgs.systemd "systemctl";
in
mkIf (cfg.enable && desktopEnabled && isWayland)
{
  programs.waybar = {
    enable = true;
    systemd.enable = true;

    # First patch disables Waybar reloading both when the SIGUSR2 event is sent
    # and when Hyprland reloads. Waybar reloading causes the bar to open twice
    # because we run Waybar with systemd. Also breaks theme switching because
    # it reloads regardless of the Hyprland disable autoreload setting.

    # The output bar patch allows for toggling the bar on specific outputs by
    # sending the SIGRTMIN+<output_number> signal. It disables the custom
    # module signal functionality that I don't use.
    package = (utils.addPatches pkgs.waybar [
      ../../../../../../patches/waybarDisableReload.patch
      ../../../../../../patches/waybarOutputBarToggle.patch
    ]).override {
      cavaSupport = false;
      evdevSupport = true;
      experimentalPatches = false;
      hyprlandSupport = true;
      inputSupport = false;
      jackSupport = false;
      mpdSupport = false;
      mprisSupport = false;
      nlSupport = true;
      pulseSupport = true;
      rfkillSupport = false;
      runTests = false;
      sndioSupport = false;
      swaySupport = false;
      traySupport = true;
      udevSupport = false;
      upowerSupport = false;
      wireplumberSupport = false;
      withMediaPlayer = false;
    };

    settings = {
      bar = {
        layer = "top";
        height = 41;
        margin = "0";
        spacing = 17;

        "hyprland/workspaces" = mkIf isHyprland {
          on-click = "activate";
          sort-by-number = true;
          active-only = false;
          format = "{icon}";
          on-scroll-up = "hyprctl dispatch workspace r-1";
          on-scroll-down = "hyprctl dispatch workspace r+1";

          format-icons = {
            TWITCH = "󰕃";
            GAME = "󱎓";
          };
        };

        "hyprland/submap" = mkIf isHyprland {
          format = "{}";
          max-length = 8;
          tooltip = false;
        };

        "hyprland/window" = mkIf isHyprland {
          max-length = 59;
          separate-outputs = true;
        };

        clock = {
          interval = 1;
          format = "{:%H:%M:%S}";
          format-alt = "{:%e %B %Y}";
          tooltip-format = "<tt><small>{calendar}</small></tt>";

          calendar = {
            mode = "month";
            mode-mon-col = 3;
            weeks-pos = "";
            on-scroll = 1;

            format = {
              months = "<span color='#${colors.base07}'><b>{}</b></span>";
              days = "<span color='#${colors.base07}'><b>{}</b></span>";
              weekdays = "<span color='#${colors.base03}'><b>{}</b></span>";
              today = "<span color='#${colors.base0B}'><b>{}</b></span>";
            };
          };

          actions = {
            on-click-right = "mode";
            on-scroll-up = "shift_up";
            on-scroll-down = "shift_down";
          };
        };

        pulseaudio = mkIf audio.enable {
          format = "<span color='#${colors.base04}'>{icon}</span> {volume:2}%{format_source}";
          format-muted = "<span color='#${colors.base08}'>󰖁</span> {volume:2}%";
          format-source = "";
          format-source-muted = "<span color='#${colors.base08}'>  󰍭</span> Muted";

          format-icons = {
            headphone = "";
            hdmi = "󰍹";

            default = [
              "<span></span>"
              "<span>󰕾</span>"
              "<span></span>"
            ];
          };

          on-click = "${getExe' pkgs.wireplumber "wpctl"} set-mute @DEFAULT_AUDIO_SINK@ toggle";
          tooltip = false;
        };

        network = {
          interval = 5;
          format = "<span color='#${colors.base04}'>󰈀</span> {bandwidthTotalBytes}";
          tooltip-format = "<span color='#${colors.base04}'>󰇚</span>{bandwidthDownBytes:>} <span color='#${colors.base04}'>󰕒</span>{bandwidthUpBytes:>}";
          max-length = 50;
        };

        cpu = {
          interval = 5;
          format = "<span color='#${colors.base04}'></span> {usage}%";
        };

        "custom/gpu" = mkIf gpuModuleEnabled {
          format = "<span color='#${colors.base04}'>󰾲</span> {}%";
          exec = "${getExe' pkgs.coreutils "cat"} /sys/class/hwmon/hwmon${toString gpu.hwmonId}/device/gpu_busy_percent";
          interval = 5;
          tooltip = false;
        };

        memory = {
          interval = 30;
          format = "<span color='#${colors.base04}'></span> {used:0.1f}GiB";
          tooltip = false;
        };

        "network#hostname" = {
          format = toUpper hostname;
          tooltip-format-ethernet = "{ipaddr}";
          tooltip-format-disconnected = "<span color='#${colors.base08}'>Disconnected</span>";
        };

        tray = {
          icon-size = 17;
          show-passive-items = true;
          spacing = 17;
        };

        "custom/poweroff" = {
          format = "⏻";
          on-click-middle = "${systemctl} poweroff";
          tooltip = false;
        };

        "custom/vpn" = mkIf wgnord.enable {
          format = "<span color='#${colors.base04}'></span> {}";
          exec = "echo '{\"text\": \"${wgnord.country}\"}'";
          exec-if = "${getExe' pkgs.iproute2 "ip"} link show wgnord > /dev/null 2>&1";
          return-type = "json";
          tooltip = false;
          interval = 5;
        };

        "custom/hypridle" = mkIf hypridle.enable {
          format = "<span color='#${colors.base04}'>󰷛 </span> {}";
          exec = "echo '{\"text\": \"Lock Inhibited\"}'";
          exec-if = "${systemctl} is-active --quiet --user hypridle && exit 1 || exit 0";
          return-type = "json";
          tooltip = false;
          interval = 5;
        };

        gamemode = mkIf gamemode.enable {
          format = "{glyph} Gamemode";
          format-alt = "{glyph} Gamemode";
          glyph = "<span color='#${colors.base04}'>󰊴</span>";
          hide-not-running = true;
          use-icon = false;
          icon-size = 0;
          icon-spacing = 0;
          tooltip = false;
        };

        modules-left = [
          "custom/fullscreen"
          "hyprland/workspaces"
          "hyprland/submap"
          "hyprland/window"
        ];

        modules-center = [
          "clock"
        ];

        modules-right =
          optional hypridle.enable "custom/hypridle"
          ++ [
            "network"
          ] ++
          optional wgnord.enable "custom/vpn" ++ [
            "cpu"
          ] ++
          optional gpuModuleEnabled "custom/gpu" ++
          optional gamemode.enable "gamemode" ++ [
            "memory"
          ] ++
          optional audio.enable "pulseaudio" ++ [
            "tray"
            "custom/poweroff"
            "network#hostname"
          ];
      };
    };
  };

  systemd.user.services.waybar = {
    # Waybar spams restarts during shutdown otherwise
    Service.Restart = mkForce "no";
  };

  darkman.switchApps.waybar = {
    paths = [ "waybar/config" "waybar/style.css" ];
    reloadScript = "${systemctl} restart --user waybar";
  };

  desktop.hyprland.settings.bind =
    let
      inherit (config.modules.desktop.hyprland) modKey;
      hyprctl = getExe' config.wayland.windowManager.hyprland.package "hyprctl";
      jaq = getExe pkgs.jaq;
      monitors = filter (m: m.mirror == null) osConfig'.device.monitors;
      # Waybar bars are ordered based on x pos so we need to sort
      sortedMonitors = sort (a: b: a.position.x < b.position.x) monitors;

      toggleActiveMonitorBar = pkgs.writeShellScript "hypr-toggle-active-monitor-waybar" ''
        focused_monitor=$(${escapeShellArg hyprctl} monitors -j | ${jaq} -r 'first(.[] | select(.focused == true) | .name)')
        # Get ID of the monitor based on x pos sort
        declare -A monitor_name_to_id
        ${concatLines (imap1 (i: m: "monitor_name_to_id[${m.name}]='${toString i}'") sortedMonitors)}
        monitor_id=''${monitor_name_to_id[$focused_monitor]}
        ${systemctl} kill --user --signal="SIGRTMIN+$monitor_id" waybar
      '';
    in
    [
      # Toggle active monitor bar
      "${modKey}, B, exec, ${toggleActiveMonitorBar}"
      # Toggle all bars
      "${modKey}SHIFT, B, exec, ${systemctl} kill --user --signal=SIGUSR1 waybar"
      # Restart waybar
      "${modKey}SHIFTCONTROL, B, exec, ${systemctl} restart --user waybar"
    ];
}
