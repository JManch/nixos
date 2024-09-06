{
  ns,
  lib,
  pkgs,
  config,
  ...
}:
let
  inherit (lib)
    mkIf
    getExe
    mkForce
    mkDefault
    ;
  inherit (config.${ns}.core) homeManager;
  cfg = config.${ns}.system.desktop;
  extensions = with pkgs.gnomeExtensions; [
    appindicator
    night-theme-switcher
    dash-to-dock
  ];
in
mkIf (cfg.enable && cfg.desktopEnvironment == "gnome") {
  services.xserver = {
    enable = true;
    displayManager.gdm.enable = true;
    displayManager.gdm.autoSuspend = cfg.suspend.enable;
    desktopManager.gnome.enable = true;
  };

  # Gnome uses network manager
  ${ns}.system.networking.useNetworkd = mkForce false;

  environment.gnome.excludePackages = with pkgs; [
    gnome-tour
    epiphany
    # Broken on nvidia, using clapper instead
    totem
  ];

  userPackages =
    extensions
    ++ (with pkgs; [
      gnome-tweaks
      clapper
    ]);

  hm = mkIf homeManager.enable {
    ${ns}.desktop.terminal = {
      exePath = mkDefault (getExe pkgs.gnome-console);
      class = mkDefault "org.gnome.Consolez";
    };

    dconf.settings =
      let
        inherit (lib.hm.gvariant) mkUint32 mkDouble;
      in
      {
        "org/gnome/desktop/peripherals/mouse" = {
          accel-profile = "flat";
        };

        "org/gnome/desktop/wm/preferences" = {
          action-middle-click-titlebar = "toggle-maximize-vertically";
          button-layout = "appmenu:minimize,maximize,close";
          # Focus follows mouse
          focus-mode = "sloppy";
          resize-with-right-button = true;
        };

        "org/gnome/mutter" = {
          edge-tiling = true;
        };

        "org/gnome/settings-daemon/plugins/color" = {
          night-light-enabled = true;
          night-light-schedule-automatic = true;
        };

        "org/gnome/settings-daemon/plugins/power" = {
          power-button-action = "interactive";
          sleep-inactive-ac-type = if cfg.suspend.enable then "suspend" else "nothing";
          sleep-inactive-ac-timeout = 1200;
        };

        "org/gnome/desktop/session" = {
          idle-delay = mkUint32 180;
        };

        "org/gnome/shell" = {
          enabled-extensions = (map (e: e.extensionUuid) extensions) ++ [
            "drive-menu@gnome-shell-extensions.gcampax.github.com"
            "launch-new-instance@gnome-shell-extensions.gcampax.github.com"
          ];
        };

        "org/gnome/shell/extensions/nightthemeswitcher/commands" = {
          enabled = true;
          sunset = "gsettings set org.gnome.desktop.interface cursor-theme Bibata-Modern-Classic";
          sunrise = "gsettings set org.gnome.desktop.interface cursor-theme Bibata-Modern-Ice";
        };

        "org/gnome/shell/extensions/nightthemeswitcher/time" = {
          manual-schedule = true;
          sunrise = mkDouble "7.0";
          sunset = mkDouble "21.0";
        };

        "org/gnome/shell/extensions/dash-to-dock" = {
          click-action = "focus-or-appspread";
          scroll-action = "cycle-windows";
          apply-custom-theme = true;
          show-trash = false;
        };

        "org/gnome/system/location" = {
          enabled = false;
        };
      };
  };
}
