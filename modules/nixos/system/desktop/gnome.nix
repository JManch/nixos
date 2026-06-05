{
  lib,
  cfg,
  pkgs,
  config,
  inputs,
  categoryCfg,
}:
let
  inherit (lib)
    ns
    mkIf
    mkForce
    mkDefault
    foldl'
    genList
    optionalAttrs
    mkEnableOption
    mkOption
    types
    ;
  inherit (config.${ns}.core) home-manager;
  extensions = with pkgs.gnomeExtensions; [
    appindicator
    night-theme-switcher
    dash-to-panel
    alphabetical-app-grid
  ];
in
{
  enableOpt = false;
  conditions = [ (categoryCfg.desktopEnvironment == "gnome") ];

  opts = {
    advancedBinds = mkEnableOption "advanced binds";

    workspaceCount = mkOption {
      type = types.ints.between 1 10;
      default = 4;
      description = "Number of Gnome workspaces to create";
    };
  };

  services.desktopManager.gnome.enable = true;
  services.displayManager.gdm = {
    enable = true;
    autoSuspend = categoryCfg.suspend.enable;
  };

  # Gnome uses network manager
  ns.system.networking.useNetworkd = mkForce false;

  environment.gnome.excludePackages = with pkgs; [
    gnome-tour
    epiphany
    # Broken on nvidia, using clapper instead
    totem
  ];

  ns.userPackages =
    extensions
    ++ (with pkgs; [
      gnome-tweaks
      clapper
    ]);

  home-manager.sharedModules = [ inputs.gnome-keybinds.homeManagerModules.default ];

  ns.hm = mkIf home-manager.enable {
    ${ns}.desktop.terminal = mkDefault "org.gnome.Terminal";

    dconf.settings =
      let
        inherit (inputs.home-manager.lib.hm.gvariant) mkUint32 mkDouble;
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
          dynamic-workspaces = false;
          num-workspaces = cfg.workspaceCount;
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
          sleep-inactive-ac-type = "nothing";
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
        };

        "org/gnome/shell/extensions/nightthemeswitcher/time" = {
          manual-schedule = true;
          sunrise = mkDouble "7.0";
          sunset = mkDouble "21.0";
        };

        "org/gnome/system/location" = {
          enabled = false;
        };
      };

    gnome-keybinds.binds =
      let
        workspaceBinds = foldl' (acc: bind: acc // bind) { } (
          genList (
            w':
            let
              w = toString (w' + 1);
            in
            {
              "switch-to-workspace-${w}" = "<Super>${if w == "10" then "0" else w}";
              "move-to-workspace-${w}" = "<Shift><Super>${if w == "10" then "0" else w}";
            }
            // optionalAttrs (w' < 9) {
              "switch-to-application-${w}" = [ ];
              "open-new-window-application-${w}" = [ ];
            }
          ) cfg.workspaceCount
        );
      in
      workspaceBinds
      // {
        toggle-maximized = "<Super>f";
        toggle-fullscreen = "<Shift><Super>f";
        show-desktop = "<Super>d";
        mic-mute = "<Super>m";
        toggle-message-tray = [ ];
        screensaver = [ ];
        switch-to-workspace-left = "<Super>Left";
        switch-to-workspace-right = "<Super>Right";
        move-to-workspace-left = "<Shift><Super>Left";
        move-to-workspace-right = "<Shift><Super>Right";
        move-to-monitor-left = "<Shift><Control><Super>Left";
        move-to-monitor-right = "<Shift><Control><Super>Right";
        toggle-tiled-left = "<Super>bracketleft";
        toggle-tiled-right = "<Super>bracketright";

        switch-to-workspace-1 = "<Super>1";
        switch-to-workspace-2 = "<Super>2";
        switch-to-workspace-3 = "<Super>3";
        switch-to-workspace-4 = "<Super>4";

        move-to-workspace-1 = "<Shift><Super>1";
        move-to-workspace-2 = "<Shift><Super>2";
        move-to-workspace-3 = "<Shift><Super>3";
        move-to-workspace-4 = "<Shift><Super>4";

        switch-to-application-1 = [ ];
        switch-to-application-2 = [ ];
        switch-to-application-3 = [ ];
        switch-to-application-4 = [ ];

        open-new-window-application-1 = [ ];
        open-new-window-application-2 = [ ];
        open-new-window-application-3 = [ ];
        open-new-window-application-4 = [ ];

        switch-applications = "<Super>Tab";
        switch-applications-backward = "<Shift><Super>Tab";
        switch-windows = "<Alt>Tab";
        switch-windows-backward = "<Shift><Alt>Tab";
      }
      // optionalAttrs cfg.advancedBinds {
        toggle-maximized = "<Super>e";
        toggle-fullscreen = "<Shift><Super>e";
        close = "<Super>w";
        toggle-tiled-left = "<Super>h";
        toggle-tiled-right = "<Super>l";
        switch-to-workspace-left = "<Super>j";
        switch-to-workspace-right = "<Super>k";
        switch-to-workspace-last = "<Super>n";
        focus-active-notification = [ ];
        move-to-workspace-last = "<Shift><Super>n";
        next = "<Super>period";
        previous = "<Super>comma";
      };
  };
}
