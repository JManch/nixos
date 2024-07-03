{ lib, pkgs, config, ... }:
let
  inherit (lib) mkIf getExe mkForce mkDefault;
  inherit (config.modules.core) homeManager;
  inherit (config.device) gpu;
  cfg = config.modules.system.desktop;
  extensions = with pkgs.gnomeExtensions; [
    hot-edge
    appindicator
    night-theme-switcher
  ];
in
mkIf (cfg.enable && cfg.desktopEnvironment == "gnome")
{
  services.xserver = {
    enable = true;
    displayManager.gdm.enable = true;
    # Suspend is temperamental on nvidia GPUs
    displayManager.gdm.autoSuspend = !(gpu.type == "nvidia");
    desktopManager.gnome.enable = true;
  };

  # Gnome uses network manager
  modules.system.networking.useNetworkd = mkForce false;

  # Only enable the power management feature on laptops
  services.upower.enable = mkForce (config.device.type == "laptop");
  services.power-profiles-daemon.enable = mkForce (config.device.type == "laptop");

  environment.gnome.excludePackages = with pkgs; [
    gnome-tour
    gnome.epiphany
  ];

  environment.systemPackages = extensions ++ [
    pkgs.gnome.gnome-tweaks
  ];

  hm = mkIf homeManager.enable {
    modules.desktop.terminal = {
      exePath = mkDefault (getExe pkgs.gnome-console);
      class = mkDefault "org.gnome.Consolez";
    };

    dconf.settings = {
      "org/gnome/desktop/peripherals/mouse" = {
        accel-profile = "flat";
      };

      "org/gnome/mutter" = {
        edge-tiling = true;
      };

      "org/gnome/settings-daemon/plugins/color" = {
        night-light-enabled = true;
        night-light-schedule-automatic = true;
      };

      # Disable auto-suspend and power button suspend on nvidia
      "org/gnome/settings-daemon/plugins/power" = mkIf (gpu.type == "nvidia") {
        power-button-action = "interactive";
        sleep-inactive-ac-type = "nothing";
      };

      "org/gnome/shell" = {
        enabled-extensions = (map (e: e.extensionUuid) extensions) ++ [
          "system-monitor@gnome-shell-extensions.gcampax.github.com"
          "drive-menu@gnome-shell-extensions.gcampax.github.com"
        ];
      };

      "org/gnome/shell/extensions/nightthemeswitcher/time" = {
        manual-schedule = false;
      };

      "org/gnome/system/location" = {
        enabled = true;
      };

      "org/gnome/desktop/wm/preferences" = {
        action-middle-click-titlebar = "toggle-maximize-vertically";
        button-layout = "appmenu:minimize,maximize,close";
        # Focus follows mouse
        focus-mode = "sloppy";
        resize-with-right-button = true;
      };
    };
  };
}
