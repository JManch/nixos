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
    optionals
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
  inherit (osConfig.${ns}.hardware) bluetooth;
  inherit (osConfig.programs) uwsm;
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
  app2unit = getExe pkgs.app2unit;

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
        # Hides the module if the format string is empty
        # Forces use of device description instead of nick name in tooltip
        # Hides the module instead of crashing when no source device exists
        "waybar-wireplumber-improvements.patch"
      ]).override
        {
          cavaSupport = false;
          inputSupport = false;
          jackSupport = false;
          mpdSupport = false;
          mprisSupport = false;
          rfkillSupport = false;
          sndioSupport = false;
          upowerSupport = false;
          pulseSupport = false;
          withMediaPlayer = false;
        };

    settings = {
      bar = {
        position = if cfg.bottom then "bottom" else "top";
        layer = "top";
        height = 42; # ideally should be divisible by scaling factor to avoid an ugly line of pixels
        margin = if cfg.float then "${gapSize} ${gapSize} 0 ${gapSize}" else "0";
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
          max-length = 60;
          separate-outputs = true;
        };

        clock = {
          interval = if (device.type != "laptop") then 1 else 60;
          format = "     {:%H:%M${optionalString (device.type != "laptop") ":%S"}}     ";
          format-alt = "   {:%e %B %Y}   ";
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

        "wireplumber#sink" = mkIf audio.enable {
          format = "<span color='#${colors.base04}'>{icon}</span> {volume:2}%";
          format-muted = "<span color='#${colors.base04}'>󰖁</span> {volume:2}%";
          format-icons = [
            "󰖀"
            "󰕾"
            "󰕾"
          ];
          on-click = "${app2unit} -t service com.saivert.pwvucontrol.desktop";
          tooltip = true;
        };

        "wireplumber#source" = mkIf audio.enable {
          node-type = "Audio/Source";
          format = "<span color='#${colors.base08}'>󰍬</span>";
          format-muted = "";
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
          on-click = mkIf (config.${ns}.programs.shell.btop.enable) "${app2unit} -t service btop.desktop";
        };

        "custom/gpu" = mkIf gpuModuleEnabled {
          format = "<span color='#${colors.base04}'>󰾲</span> {}%";
          exec = "${getExe' pkgs.coreutils "cat"} /sys/class/drm/renderD128/device/gpu_busy_percent";
          interval = 5;
          tooltip = false;
          on-click = mkIf (config.${ns}.programs.shell.btop.enable) "${app2unit} -t service btop.desktop";
        };

        # The upower module has less configuration
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
          tooltip = true;
          format-time = " {H}:{m}";
          tooltip-format = "{power:4.2f}W{time}";
          on-click = mkIf (config.${ns}.programs.shell.btop.enable) "${app2unit} -t service btop.desktop";
        };

        memory = {
          format = "<span color='#${colors.base04}'></span> {used:0.1f}GiB";
          interval = 30;
          tooltip = false;
          on-click = mkIf (config.${ns}.programs.shell.btop.enable) "${app2unit} -t service btop.desktop";
        };

        bluetooth = (mkIf bluetooth.enable) {
          format = "";
          format-on = optionalString (device.type == "laptop") "<span color='#${colors.base04}'>󰂯</span>";
          format-connected = "<span color='#${colors.base04}'>󰂱</span> {num_connections}";
          on-click = "${app2unit} -t service bluetui.desktop";
          on-click-right = "${getExe' pkgs.bluez "bluetoothctl"} power off";
          tooltip-format = "{controller_alias}";
          tooltip-format-connected = "{device_enumerate}";
          tooltip-format-enumerate-connected = "{device_alias}";
        };

        "network#wifi" = mkIf networking.wireless.enable {
          format = "";
          format-wifi = "<span color='#${colors.base04}'>{icon}</span> {signalStrength}%";
          format-disconnected =
            if networking.wireless.disableOnBoot then "" else "<span color='#${colors.base04}'>󰤮</span> ";
          format-icons = [
            "󰤯"
            "󰤟"
            "󰤢"
            "󰤥"
            "󰤨"
          ];
          tooltip = true;
          tooltip-format-wifi = "{essid} {frequency}GHz";
          interval = 60;
          interface = networking.wireless.interface;
          on-click =
            if networking.wireless.backend == "wpa_supplicant" then
              "${app2unit} -t service wpa_gui.desktop"
            else
              "${app2unit} -t service impala.desktop";
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
          on-click = "${systemctl} ${cfg.powerOffMethod}";
          on-click-middle = "${systemctl} poweroff";
          tooltip = false;
        };

        "custom/vpn" = mkIf wgnord.enable {
          format = "<span color='#${colors.base04}'></span> {}";
          exec = "echo '{\"text\": \"'$(</tmp/wgnord-country)'\"}'";
          exec-if = "${getExe' pkgs.iproute2 "ip"} link show wgnord > /dev/null 2>&1";
          return-type = "json";
          tooltip-format = "Disconnect";
          interval = 30;
          on-click = "wgnord-down";
        };

        "custom/locker" = mkIf (locker.package != null) {
          format = "<span color='#${colors.base04}'>󰷛 </span> {}";
          exec = ''${systemctl} is-active --quiet --user inhibit-lock && echo -n "Inhibited" || echo -n ""'';
          interval = 30;
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
          ++ optionals audio.enable [
            "wireplumber#sink"
            "wireplumber#source"
          ]
          ++ optional (battery != null) "battery"
          ++ optional (bluetooth.enable) "bluetooth"
          ++ optional networking.wireless.enable "network#wifi"
          ++ [
            "tray"
            "custom/poweroff"
            "custom/hostname"
          ];
      };
    };
  };

  systemd.user.services.waybar = {
    Unit = {
      Requisite = [ "graphical-session.target" ];
      # We do not want PartOf=tray.target if we're using UWSM
      PartOf = mkIf uwsm.enable (mkForce [ "graphical-session.target" ]);
      After = mkForce [ "graphical-session.target" ];
      X-Reload-Triggers = mkForce [ ];
    };

    Service = {
      Slice = "app${sliceSuffix osConfig}.slice";
      ExecReload = mkForce [ ];
    };

    Install.WantedBy = mkIf uwsm.enable (mkForce [ "graphical-session.target" ]);
  };

  ns.desktop.darkman.switchApps.waybar = {
    paths = [
      ".config/waybar/config"
      ".config/waybar/style.css"
    ];
    reloadScript = "${systemctl} restart --user waybar";
  };

  ns.desktop.hyprland = {
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
          "${modKey}, B, exec, ${toggleActiveMonitorBar}"
          "${modKey}SHIFTCONTROL, B, exec, ${systemctl} restart --user waybar"
        ];
      };

    socketListenerExtraLines = ''
      ${monitorNameToNumMap}
      declare -A monitor_last_workspace
      declare -A waybar_schedule_monitor_unhide
    '';

    # Update bar auto toggle when active workspace changes
    eventScripts.workspace =
      mkIf (cfg.autoHideWorkspaces != [ ]) # bash
        ''
          # waybar auto toggle workspace
          workspace_name="''${args[0]}"
          focused_monitor=$(${hyprctl} monitors -j | ${jaq} -r 'first(.[] | select(.focused == true) | .name)')
          last_workspace_name=''${monitor_last_workspace["$focused_monitor"]:-}
          monitor_last_workspace["$focused_monitor"]=$workspace_name

          monitor_num=''${waybar_monitor_name_to_num["$focused_monitor"]}
          if [[ ${
            concatMapStringsSep " || " (workspace: "$workspace_name == \"${workspace}\"") cfg.autoHideWorkspaces
          } ]]; then
            # hide the bar
            systemctl kill --user --signal="SIGRTMIN+$(((0 << 3) | monitor_num ))" waybar
          else
            # If the last workspace on this monitor was an auto hide workspace
            if [[ ${
              concatMapStringsSep " || " (
                workspace: "$last_workspace_name == \"${workspace}\""
              ) cfg.autoHideWorkspaces
            } ]] || [[ ''${waybar_schedule_monitor_unhide["$focused_monitor"]:-false} == "true" ]]; then
              fullscreen_mode=$(${hyprctl} workspaces -j | ${jaq} -r "first(.[] | select(.name == \"$workspace_name\") | .fullscreenMode)")
              # if active workspace is not maximised fullscreen
              if [[ $fullscreen_mode != "2" ]]; then
                # unhide the bar
                systemctl kill --user --signal="SIGRTMIN+$(((1 << 3) | monitor_num ))" waybar
                waybar_schedule_monitor_unhide["$focused_monitor"]=false
              else
                waybar_schedule_monitor_unhide["$focused_monitor"]=true
              fi
            fi
          fi
        '';
  };
}
