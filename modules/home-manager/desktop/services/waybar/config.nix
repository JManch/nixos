{
  lib,
  pkgs,
  config,
  hostname,
  osConfig,
  desktopEnabled,
  ...
}:
let
  inherit (lib)
    ns
    mkIf
    optional
    getExe'
    toUpper
    mkForce
    getExe
    concatLines
    sort
    concatMapStringsSep
    ;
  inherit (lib.${ns}) addPatches sliceSuffix getMonitorByName;
  inherit (config.${ns}) desktop;
  inherit (desktop.services) hypridle;
  inherit (osConfig.${ns}.device)
    gpu
    monitors
    backlight
    battery
    ;
  cfg = desktop.services.waybar;
  isHyprland = lib.${ns}.isHyprland config;
  colors = config.colorScheme.palette;
  gapSize = toString desktop.style.gapSize;

  audio = osConfig.${ns}.system.audio;
  wgnord = osConfig.${ns}.services.wgnord;
  gamemode = osConfig.${ns}.programs.gaming.gamemode;
  gpuModuleEnabled = (gpu.type == "amd") && (gpu.hwmonId != null);

  systemctl = getExe' pkgs.systemd "systemctl";
  hyprctl = getExe' pkgs.hyprland "hyprctl";
  jaq = getExe pkgs.jaq;
  brightnessctl = getExe pkgs.brightnessctl;

  monitorNameToNumMap = # bash
    ''
      declare -A waybar_monitor_name_to_num
      ${concatLines (
        map (
          m:
          "waybar_monitor_name_to_num[${m.name}]='${
            if m.mirror == null then toString m.number else toString (getMonitorByName osConfig m.mirror).number
          }'"
        ) monitors
      )}
    '';
in
mkIf (cfg.enable && desktopEnabled) {
  programs.waybar = {
    enable = true;
    systemd.enable = true;

    # First patch disables Waybar reloading both when the SIGUSR2 event is sent
    # and when Hyprland reloads. Waybar reloading causes the bar to open twice
    # because we run Waybar with systemd. Also breaks theme switching because
    # it reloads regardless of the Hyprland disable autoreload setting.

    # The output bar patch allows for hiding, showing, or toggling the bar on
    # specific outputs by sending an encoded signal. The signal is 5 bits where
    # the first two bits are the action and the remaining 3 bits are the output
    # number. Actions are hide(0), show(1), toggle(2). This patch disables the
    # custom module signal functionality that I don't use.
    package =
      (addPatches pkgs.waybar [
        ../../../../../patches/waybarDisableReload.patch
        (pkgs.substituteAll {
          src = ../../../../../patches/waybarSignalToggle.patch;
          sortedMonitors = concatMapStringsSep ", " (m: "\"${m.name}\"") (
            sort (a: b: a.number < b.number) monitors
          );
        })
      ]).override
        {
          cavaSupport = false;
          inputSupport = false;
          jackSupport = false;
          mpdSupport = false;
          mprisSupport = false;
          rfkillSupport = false;
          sndioSupport = false;
          swaySupport = false;
          upowerSupport = false;
          wireplumberSupport = false;
          withMediaPlayer = false;
        };

    settings = {
      bar = {
        layer = "top";
        height = 41;
        margin = "${gapSize} ${gapSize} 0 ${gapSize}";
        spacing = 17;

        "hyprland/workspaces" = mkIf isHyprland {
          on-click = "activate";
          sort-by-number = true;
          active-only = false;
          format = "{icon}";
          on-scroll-up = "${hyprctl} dispatch workspace m-1";
          on-scroll-down = "${hyprctl} dispatch workspace m+1";

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

        backlight = mkIf (backlight != null) {
          device = backlight;
          format = "<span color='#${colors.base04}'>{icon}</span> {percent}%";
          format-icons = [
            "󰃞"
            "󰃟"
            "󰃠"
          ];
          on-scroll-up = "${brightnessctl} set +1%";
          on-scroll-down = "${brightnessctl} set 1%-";
          tooltip = false;
        };

        pulseaudio = mkIf audio.enable {
          format = "<span color='#${colors.base04}'>{icon}</span> {volume:2}%{format_source}";
          format-muted = "<span color='#${colors.base08}'>󰖁</span> {volume:2}%";
          format-source = "<span color='#${colors.base04}'>  󰍬</span> Unmuted";
          format-source-muted = "";

          format-icons = {
            hdmi = "󰍹";

            default = [
              "󰖀"
              "󰕾"
              "󰕾"
            ];
          } // cfg.audioDeviceIcons;

          on-click = "${getExe pkgs.pavucontrol}";
          on-click-right = "${getExe' pkgs.wireplumber "wpctl"} set-mute @DEFAULT_AUDIO_SINK@ toggle";
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

        battery = mkIf (battery != null) {
          format = "<span color='#${colors.base04}'>{icon}</span> {capacity}%";
          format-charging = "<span color='#${colors.base04}'>󰂄</span> {capacity}%";
          format-icons = [
            "󰁺"
            "󰁻"
            "󰁼"
            "󰁽"
            "󰁾"
            "󰁿"
            "󰂀"
            "󰂁"
            "󰂂"
            "󰁹"
          ];
          states = {
            warning = 25;
            critical = 15;
          };
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
          on-click = "${systemctl} suspend";
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

        modules-center = [ "clock" ];

        modules-right =
          optional hypridle.enable "custom/hypridle"
          ++ [ "network" ]
          ++ optional wgnord.enable "custom/vpn"
          ++ [ "cpu" ]
          ++ optional gpuModuleEnabled "custom/gpu"
          ++ optional gamemode.enable "gamemode"
          ++ [ "memory" ]
          ++ optional (backlight != null) "backlight"
          ++ optional audio.enable "pulseaudio"
          ++ optional (battery != null) "battery"
          ++ [
            "tray"
            "custom/poweroff"
            "network#hostname"
          ];
      };
    };
  };

  systemd.user.services.waybar = {
    Unit.After = mkForce [ "graphical-session.target" ];
    Unit.X-Restart-Triggers = mkForce [ ];
    Service = {
      Slice = "app${sliceSuffix osConfig}.slice";
      ExecReload = mkForce [ ];
    };
  };

  darkman.switchApps.waybar = {
    paths = [
      ".config/waybar/config"
      ".config/waybar/style.css"
    ];
    reloadScript = "${systemctl} restart --user waybar";
  };

  desktop.hyprland.settings =
    let
      inherit (config.${ns}.desktop.hyprland) modKey;

      toggleActiveMonitorBar = pkgs.writeShellScript "hypr-toggle-active-monitor-waybar" ''
        focused_monitor=$(${hyprctl} monitors -j | ${jaq} -r 'first(.[] | select(.focused == true) | .name)')
        # Get ID of the monitor based on x pos sort
        ${monitorNameToNumMap}
        monitor_num=''${waybar_monitor_name_to_num[$focused_monitor]}
        ${systemctl} kill --user --signal="SIGRTMIN+$(((2 << 3) | monitor_num))" waybar
      '';
    in
    {
      bind = [
        # Toggle active monitor bar
        "${modKey}, B, exec, ${toggleActiveMonitorBar}"
        # Toggle all bars
        "${modKey}SHIFT, B, exec, ${systemctl} kill --user --signal=SIGUSR1 waybar"
        # Restart waybar
        "${modKey}SHIFTCONTROL, B, exec, ${systemctl} restart --user waybar"
      ];
    };

  ${ns}.desktop.hyprland =
    let
      updateMonitorBar = # bash
        ''
          update_monitor_bar() {
            ${monitorNameToNumMap}
            monitor_num=''${waybar_monitor_name_to_num["$1"]}
            if [[ ${
              concatMapStringsSep "||" (workspace: "\"$2\" == \"${workspace}\"") cfg.autoHideWorkspaces
            } ]]; then
              systemctl kill --user --signal="SIGRTMIN+$(((0 << 3) | monitor_num ))" waybar
            else
              systemctl kill --user --signal="SIGRTMIN+$(((1 << 3) | monitor_num ))" waybar
            fi
          }
        '';
    in
    {
      # Update bar auto toggle when active workspace changes
      eventScripts.workspace =
        optional (cfg.autoHideWorkspaces != [ ])
          (pkgs.writeShellScript "hypr-waybar-auto-toggle-workspace" ''
            ${updateMonitorBar}
            workspace_name="$1"
            focused_monitor=$(${hyprctl} monitors -j | ${jaq} -r 'first(.[] | select(.focused == true) | .name)')
            update_monitor_bar "$focused_monitor" "$workspace_name"
          '').outPath;

      # Update bar auto toggle when workspace is moved between monitors
      eventScripts.moveworkspace =
        optional (cfg.autoHideWorkspaces != [ ])
          (pkgs.writeShellScript "hypr-waybar-auto-toggle-moveworkspace" ''
            ${updateMonitorBar}
            workspace_name="$1"
            monitor_name="$2"
            waybar_update_monitor_bar "$monitor_name" "$workspace_name"

            # unhide/hide the bar on the monitor where this workspace came
            # from through all monitors and update the bar based on their
            # active workspace.
            active_workspaces=$(${hyprctl} monitors -j | ${jaq} -r ".[] | select((.disabled == false) and (.name != \"$monitor_name\")) | \"\(.name) \(.activeWorkspace.name)\"")
            while IFS= read -r line; do
              read -r monitor_name workspace_name <<< "$line"
              update_monitor_bar "$monitor_name" "$workspace_name"
            done <<< "$active_workspaces"
          '').outPath;
    };
}
