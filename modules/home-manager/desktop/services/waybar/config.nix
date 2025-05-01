{
  lib,
  cfg,
  pkgs,
  config,
  hostname,
  osConfig,
}:
let
  inherit (lib)
    ns
    mkIf
    optional
    getExe'
    toUpper
    optionalString
    mkForce
    getExe
    concatLines
    sort
    concatMapStringsSep
    ;
  inherit (lib.${ns}) addPatches sliceSuffix getMonitorByName;
  inherit (config.${ns}) desktop;
  inherit (desktop.programs) locker;
  inherit (osConfig.${ns}.core) device;
  inherit (osConfig.${ns}.system) networking;
  inherit (device)
    gpu
    monitors
    backlight
    battery
    ;
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
{
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
        "waybar-disable-reload.patch"
        (pkgs.replaceVars ../../../../../patches/waybar-signal-toggle.patch {
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
          format = "{:%H:%M${optionalString (device.type == "desktop") ":%S"}}";
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
          tooltip = false;
        };

        pulseaudio = mkIf audio.enable {
          format = "<span color='#${
            if audio.alwaysMuteSink then colors.base08 else colors.base04
          }'>{icon}</span> {volume:2}%{format_source}";
          format-muted = "<span color='#${
            if audio.alwaysMuteSink then colors.base04 else colors.base08
          }'>󰖁</span> {volume:2}%{format_source}";
          format-source = "<span color='#${colors.base08}'>  󰍬</span>";
          format-source-muted = "";

          format-icons = {
            hdmi = "󰍹";
            headset = "󰋎";

            default = [
              "󰖀"
              "󰕾"
              "󰕾"
            ];
          } // cfg.audioDeviceIcons;

          on-click = "${getExe pkgs.app2unit} com.saivert.pwvucontrol.desktop";
          tooltip = true;
        };

        # not enough space on laptops for this
        network = mkIf (device.type != "laptop") {
          interval = 5;
          format = "<span color='#${colors.base04}'>󰈀</span> {bandwidthTotalBytes}";
          tooltip-format = "<span color='#${colors.base04}'>󰇚</span>{bandwidthDownBytes:>} <span color='#${colors.base04}'>󰕒</span>{bandwidthUpBytes:>}";
          max-length = 50;
        };

        cpu = {
          interval = 5;
          format = "<span color='#${colors.base04}'></span> {usage}%";
          tooltip = false;
        };

        "custom/gpu" = mkIf gpuModuleEnabled {
          format = "<span color='#${colors.base04}'>󰾲</span> {}%";
          exec = "${getExe' pkgs.coreutils "cat"} /sys/class/drm/renderD128/device/gpu_busy_percent";
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
          interval = 60;
          tooltip = false;
        };

        memory = {
          format = "<span color='#${colors.base04}'></span> {used:0.1f}GiB";
          interval = 30;
          tooltip = false;
        };

        "network#wifi" = mkIf (networking.wireless.enable && device.type == "laptop") {
          format = "";
          format-wifi = "<span color='#${colors.base04}'>{icon}</span> {signaldBm}dBm";
          format-disconnected = "<span color='#${colors.base04}'>󰤮</span> ";
          format-icons = [
            "󰤯"
            "󰤟"
            "󰤢"
            "󰤥"
            "󰤨"
          ];
          tooltip = true;
          tooltip-format-wifi = "{essid} {frequency}GHz";
          interval = 10;
          interface = networking.wireless.interface;
          on-click = "${getExe pkgs.app2unit} wpa_gui.desktop";
        };

        tray = {
          icon-size = 17;
          show-passive-items = true;
          spacing = 17;
        };

        "custom/hostname" = {
          format = toUpper hostname;
          tooltip = false;
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

        "custom/locker" = mkIf (locker.package != null) {
          format = "<span color='#${colors.base04}'>󰷛 </span> {}";
          exec = ''${systemctl} is-active --quiet --user inhibit-lock && echo -n "Lock Inhibited" || echo -n ""'';
          interval = 5;
          tooltip = false;
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
          optional (locker.package != null) "custom/locker"
          ++ optional (device.type != "laptop") "network"
          ++ optional wgnord.enable "custom/vpn"
          ++ [ "cpu" ]
          ++ optional gpuModuleEnabled "custom/gpu"
          ++ optional gamemode.enable "gamemode"
          ++ [ "memory" ]
          ++ optional (backlight != null) "backlight"
          ++ optional audio.enable "pulseaudio"
          ++ optional (battery != null) "battery"
          ++ optional (networking.wireless.enable && device.type == "laptop") "network#wifi"
          ++ [
            "tray"
            "custom/poweroff"
            "custom/hostname"
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

  ns.desktop.darkman.switchApps.waybar = {
    paths = [
      ".config/waybar/config"
      ".config/waybar/style.css"
    ];
    reloadScript = "${systemctl} restart --user waybar";
  };

  ns.desktop.hyprland =
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
      settings =
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
