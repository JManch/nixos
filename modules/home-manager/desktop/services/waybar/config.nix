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
    sort
    concatMapStringsSep
    ;
  inherit (lib.${ns})
    addPatches
    sliceSuffix
    mkHyprExec
    ;
  inherit (config.${ns}) desktop;
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
  gpuModuleEnabled = (gpu.type == "amd") && (gpu.hwmonId != null);
  powerProfilesEnabled =
    osConfig.services.tlp.enable || osConfig.services.power-profiles-daemon.enable;

  notify-send = getExe pkgs.libnotify;
  systemctl = getExe' pkgs.systemd "systemctl";
  hyprctl = getExe' pkgs.hyprland "hyprctl";
  app2unit = getExe pkgs.app2unit;
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
      (addPatches pkgs.waybar (
        [
          "waybar-disable-reload.patch"
          (pkgs.replaceVars ../../../../../patches/waybar-signal-toggle.patch {
            sortedMonitors = concatMapStringsSep ", " (m: "\"${m.name}\"") (
              sort (a: b: a.number < b.number) monitors
            );
          })
          # Forces use of device description instead of nick name in tooltip
          "waybar-wireplumber-device-description.patch"
          # Hides the wireplumber box when the format is empty
          "waybar-wireplumber-hide-box.patch"
          # Removes constant logging when our `tomat watch` commands fails if the
          # service is not running
          "waybar-disable-stopped-log.patch"
          # Waybar updates component widgets every interval, regardless of
          # whether their values have changed. This triggers a redraw and damages
          # the bar in the compositor. On my laptop this causes my GPU to jump
          # into S1 state every interval. Doesn't seem to affect powerdraw but it
          # slightly bumps clock speed and probably isn't optimal. This patch
          # removes the unnecessary redraws.
          "waybar-reduce-redraws.patch"
        ]
        # Do not update CPU usage value if it is <= 3% to reduce redraws
        ++ optional (device.type == "laptop") "waybar-less-cpu-updates.patch"
      )).override
        {
          # cavaSupport = false;
          # inputSupport = false;
          # jackSupport = false;
          # mpdSupport = false;
          # mprisSupport = false;
          # rfkillSupport = false;
          # sndioSupport = false;
          # upowerSupport = false;
          # pulseSupport = false;
          # withMediaPlayer = false;
          # runTests = false;
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
          tooltip = false;
          on-scroll-up = "${hyprctl} dispatch 'hl.dsp.focus({workspace = \"m-1\"})' >/dev/null";
          on-scroll-down = "${hyprctl} dispatch 'hl.dsp.focus({workspace = \"m+1\"})' >/dev/null";
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
          exec =
            # Reduce redraws on laptops
            if (device.type == "laptop") then
              "val=$(cat /sys/class/drm/renderD128/device/gpu_busy_percent); [[ $val -le 3 ]] && echo 0 || echo $val"
            else
              "cat /sys/class/drm/renderD128/device/gpu_busy_percent";
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
          on-click-right = "${getExe' pkgs.bluez "bluetoothctl"} power off && ${notify-send} --transient --urgency=critical -t 5000 'Bluetooth' 'Powered off'";
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

        power-profiles-daemon = mkIf powerProfilesEnabled {
          format = toUpper hostname;
          tooltip-format = "Power profile: {profile}";
          tooltip = true;
        };

        "custom/hostname" = mkIf (!powerProfilesEnabled) {
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

        modules-left = [
          "hyprland/workspaces"
          "hyprland/submap"
          "hyprland/window"
        ];

        modules-center = [ "clock" ];

        modules-right =
          optional (device.type != "laptop") "network"
          ++ optional wgnord.enable "custom/vpn"
          ++ [ "cpu" ]
          ++ optional gpuModuleEnabled "custom/gpu"
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
          ]
          ++ [ (if powerProfilesEnabled then "power-profiles-daemon" else "custom/hostname") ];
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
    reloadScript = "${systemctl} restart --user --no-block waybar";
  };

  ns.desktop.hyprland = {
    binds = [
      (mkHyprExec "mod_shift_ctrl" "B" "systemctl restart --user waybar")
    ];

    extraConf = # lua
      ''
        do
          -- Maps monitor name -> waybar output number
          local output = {}
          for num, m in pairs(monitors) do
            output[m.name] = num
          end

          -- Signal encodes a 3-bit action (hide 0, show 1, toggle 2) then the
          -- 3-bit output.
          local function signal(out, action)
            hl.exec_cmd("systemctl kill --user --signal=SIGRTMIN+" .. (action * 8 + out) .. " waybar")
          end

          -- Toggle the bar on the focused monitor
          hl.bind(mod .. " + B", function()
            local mon = hl.get_active_monitor()
            if mon ~= nil and output[mon.name] ~= nil then
              signal(output[mon.name], 2)
            end
          end)

          -- Auto hide/show the bar as the active workspace changes
          local auto_hide = { ${
            concatMapStringsSep ", " (workspace: ''["${workspace}"] = true'') cfg.autoHideWorkspaces
          } }
          local last = {}
          local scheduled = {}

          hl.on("workspace.active", function(ws)
            local mon = ws.monitor
            if mon == nil then return end
            local out = output[mon.name]
            if out == nil then return end

            local prev = last[mon.name]
            last[mon.name] = ws.name

            if auto_hide[ws.name] then
              signal(out, 0) -- hide the bar
            elseif auto_hide[prev] or scheduled[mon.name] then
              -- don't unhide over a maximised-fullscreen window; defer instead
              if ws.fullscreen_mode == 2 then
                scheduled[mon.name] = true
              else
                signal(out, 1) -- unhide the bar
                scheduled[mon.name] = false
              end
            end
          end)
        end
      '';
  };
}
