{ lib
, pkgs
, config
, hostname
, nixosConfig
, ...
}:
let
  cfg = config.modules.desktop.waybar;
  desktopCfg = config.modules.desktop;
  osDesktopEnabled = nixosConfig.usrEnv.desktop.enable;
  isWayland = lib.fetchers.isWayland config;
  colors = config.colorscheme.colors;
  sessionTarget = lib.fetchers.getDesktopSessionTarget config;
  optional = lib.lists.optional;

  audio = nixosConfig.modules.system.audio;
  wgnord = nixosConfig.modules.services.wgnord;
  easyeffects = config.modules.services.easyeffects;
in
lib.mkIf (osDesktopEnabled && isWayland && cfg.enable)
{
  programs.waybar = {
    enable = true;
    systemd = {
      enable = true;
      target = sessionTarget;
    };
    settings = {
      bar =
        let
          gapSize = builtins.toString desktopCfg.style.gapSize;
        in
        {
          layer = "top";
          height = 45;
          # margin = "${gapSize} ${gapSize} 0 ${gapSize}";
          margin = "0";
          spacing = 17;
          "hyprland/workspaces" = {
            "on-click" = "activate";
            "sort-by-number" = true;
            "active-only" = false;
            # TODO: Configure this modularly
            "persistent-workspaces" = {
              "1" = [
                "DP-2"
              ];
              "3" = [
                "DP-2"
              ];
              "2" = [
                "HDMI-A-1"
              ];
              "4" = [
                "HDMI-A-1"
              ];
            };
          };
          "hyprland/submap" = {
            format = "{}";
            "max-length" = 8;
            tooltip = false;
          };
          "hyprland/window" = {
            "max-length" = 59;
            "separate-outputs" = true;
          };
          clock = {
            interval = 1;
            format = "{:%H:%M:%S}";
            "format-alt" = "{:%e %B %Y}";
            "tooltip-format" = "<tt><small>{calendar}</small></tt>";
            calendar = {
              mode = "month";
              "mode-mon-col" = 3;
              "weeks-pos" = "";
              "on-scroll" = 1;
              format = {
                months = "<span color='#${colors.base07}'><b>{}</b></span>";
                days = "<span color='#${colors.base07}'><b>{}</b></span>";
                weekdays = "<span color='#${colors.base03}'><b>{}</b></span>";
                today = "<span color='#${colors.base0B}'><b>{}</b></span>";
              };
            };
            actions = {
              "on-click-right" = "mode";
              "on-scroll-up" = "shift_up";
              "on-scroll-down" = "shift_down";
            };
          };
          pulseaudio = lib.mkIf audio.enable {
            format = "<span color='#${colors.base04}'>{icon}</span> {volume:2}%";
            "format-muted" = "<span color='#${colors.base08}' size='large'>󰖁</span> {volume:2}%";
            "format-icons" = {
              headphone = "";
              hdmi = "󰍹";
              default = [
                "<span size='large'></span>"
                "<span size='large'>󰕾</span>"
                "<span size='large'></span>"
              ];
            };
            "on-click" = "${pkgs.pulseaudio}/bin/pactl set-sink-mute @DEFAULT_SINK@ toggle";
            tooltip = false;
          };
          network = {
            interval = 5;
            format = "<span color='#${colors.base04}'>󰈀</span> {bandwidthTotalBytes}";
            "tooltip-format" = "<span color='#${colors.base0D}'>󰇚</span>{bandwidthDownBytes:>} <span color='#59c2ff'>󰕒</span>{bandwidthUpBytes:>}";
            "max-length" = 50;
          };
          cpu = {
            interval = 5;
            format = "<span color='#${colors.base04}'></span> {usage}%";
          };
          memory = {
            interval = 30;
            format = "<span color='#${colors.base04}'></span> {used:0.1f}GiB";
          };
          "network#hostname" = {
            "format-ethernet" = "${lib.toUpper hostname}";
            "format-disconnected" = "<span color='#${colors.base08}'>${lib.toUpper hostname}</span>";
            "tooltip-format-ethernet" = "<span color='#${colors.base0B}'>{ipaddr}</span>";
            "tooltip-format-disconnected" = "<span color='#${colors.base08}'>Disconnected</span>";
          };
          tray = {
            "icon-size" = 19;
            "show-passive-items" = true;
            spacing = 17;
          };
          "custom/poweroff" = {
            format = "⏻";
            "on-click-middle" = "${pkgs.systemd}/bin/systemctl poweroff";
            tooltip = "Shutdown";
          };
          "custom/vpn" = lib.mkIf wgnord.enable {
            format = "<span color='#${colors.base04}'></span> {}";
            exec = "${pkgs.coreutils}/bin/echo '{\"text\": \"${wgnord.country}\"}'";
            exec-if = "${pkgs.iproute2}/bin/ip link show wgnord > /dev/null 2>&1";
            return-type = "json";
            tooltip = false;
            interval = 5;
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
            optional wgnord.enable "custom/vpn" ++
            [
              "network"
              "cpu"
              "memory"
            ] ++
            optional audio.enable "pulseaudio" ++
            optional easyeffects.enable "custom/easyeffects" ++
            [
              "tray"
              "custom/poweroff"
              "network#hostname"
            ];
        };
    };
  };
}
