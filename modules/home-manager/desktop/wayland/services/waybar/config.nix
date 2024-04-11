{ lib
, pkgs
, config
, hostname
, osConfig
, ...
}:
let
  inherit (lib) mkIf fetchers optional remove getExe' toUpper;
  inherit (osConfig.device) gpu;
  cfg = desktopCfg.services.waybar;
  desktopCfg = config.modules.desktop;
  isWayland = fetchers.isWayland config;
  isHyprland = desktopCfg.windowManager == "Hyprland";
  colors = config.colorscheme.palette;

  audio = osConfig.modules.system.audio;
  wgnord = osConfig.modules.services.wgnord;
  gamemode = osConfig.modules.programs.gaming.gamemode;
  gpuModuleEnabled = (gpu.type == "amd") && (gpu.hwmonId != null);
in
mkIf (cfg.enable && osConfig.usrEnv.desktop.enable && isWayland)
{
  programs.waybar = {
    enable = true;
    systemd.enable = true;

    package = (pkgs.waybar.overrideAttrs (o: {
      version = "2024-02-23";
      buildInputs = o.buildInputs ++ [ pkgs.pipewire ];

      src = pkgs.fetchFromGitHub {
        owner = "Alexays";
        repo = "Waybar";
        rev = "793394c862b7ed1b2892d8815101a4567373092c";
        hash = "sha256-VryxmTIxBnLRmpVfYYMl0WyJFLz0OJFaVMFp6W0rSdc=";
      };

      mesonFlags = (remove "-Dgtk-layer-shell=enabled" o.mesonFlags)
        ++ lib.mapAttrsToList lib.mesonEnable {
        "libevdev" = false;
      };
    })).override {
      cavaSupport = false;
      evdevSupport = false;
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
          format-source-muted = "<span color='#${colors.base08}'> 󰍭</span> Muted";

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
          on-click-middle = "${getExe' pkgs.systemd "systemctl"} poweroff";
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

        modules-right = [
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
    Service.Restart = lib.mkForce "no";
  };

  desktop.hyprland.settings.bind =
    let
      inherit (config.modules.desktop.hyprland) modKey;
      systemctl = getExe' pkgs.systemd "systemctl";
    in
    [
      # Toggle waybar
      "${modKey}, B, exec, ${systemctl} kill --user --signal=SIGUSR1 waybar"
      # Restart waybar
      "${modKey}SHIFTCONTROL, B, exec, ${systemctl} restart --user waybar"
    ];
}
