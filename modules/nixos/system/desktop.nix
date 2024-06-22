{ lib
, config
, inputs
, username
, ...
}:
let
  inherit (lib) mkIf mkForce mkMerge fetchers;
  inherit (config.usrEnv) homeManager;
  inherit (homeDesktopCfg.programs) swaylock hyprlock;
  cfg = config.modules.system.desktop;
  homeConfig = config.home-manager.users.${username};
  homeDesktopCfg = homeConfig.modules.desktop;
  isWayland = fetchers.isWayland config;
  hyprlandPackage = homeConfig.wayland.windowManager.hyprland.package;
  windowManager = if homeManager.enable then homeDesktopCfg.windowManager else null;
in
{
  imports = [
    inputs.hyprland.nixosModules.default
  ];

  config = mkIf cfg.enable (mkMerge [
    {
      # Enables wayland for all apps that support it
      environment.sessionVariables.NIXOS_OZONE_WL = mkIf isWayland "1";
    }

    (mkIf homeManager.enable {
      security.pam.services.swaylock = mkIf (isWayland && swaylock.enable) { };
      security.pam.services.hyprlock = mkIf (isWayland && hyprlock.enable) { };

      # We configure xdg portal in home-manager
      xdg.portal.enable = mkForce false;

      # Necessary for xdg-portal home-manager module to work with useUserPackages enabled
      # https://github.com/nix-community/home-manager/pull/5184
      # NOTE: When https://github.com/nix-community/home-manager/pull/2548 gets
      # merged this may no longer be needed
      environment.pathsToLink = [ "/share/xdg-desktop-portal" "/share/applications" ];
    })

    (mkIf (cfg.desktopEnvironment == "xfce") {
      services.xserver = {
        enable = true;
        displayManager.defaultSession = "xfce";

        desktopManager = {
          xterm.enable = false;
          xfce = {
            enable = true;
            noDesktop = false;
          };
        };
      };
    })

    (mkIf (cfg.desktopEnvironment == "plasma") {
      services.xserver = {
        displayManager = {
          defaultSession = "plasma";
          sddm.enable = true;
        };

        desktopManager = {
          plasma5.enable = true;
        };
      };
    })

    (mkIf (cfg.desktopEnvironment == "gnome") {
      services.xserver = {
        enable = true;
        displayManager.gdm.enable = true;
        desktopManager.gnome.enable = true;
      };

      # Gnome uses network manager
      modules.system.networking.useNetworkd = mkForce false;

      # Only enable the power management feature on laptops
      services.upower.enable = mkForce (config.device.type == "laptop");
      services.power-profiles-daemon.enable = mkForce (config.device.type == "laptop");
    })

    (mkIf (windowManager == "Hyprland") {
      # The purpose of enabling hyprland here (in addition to enabling it in
      # home-manager) is to create the hyprland.desktop session file which
      # enables login GUI managers to launch hyprland. However we use greetd
      # which is unique in the sense that it doesn't use session files. Instead
      # it uses a manually-configured launch command. Other login managers
      # would let the user pick a desktop session from a list of options
      # (generated from the .desktop session files).
      #
      # Ultimately this means that enabling hyprland on the system-level is
      # unnecessary if we're using greetd. Regardless, we enable it for
      # compatibility with other login managers.
      programs.hyprland = {
        enable = true;
        package = hyprlandPackage;
        # Extra variables are required in the dbus and systemd environment for
        # xdg-open to work using portals (the preferred method). This option
        # adds them to the systemd user environment.
        # https://github.com/NixOS/nixpkgs/issues/160923
        # https://github.com/hyprwm/Hyprland/issues/2800
        systemd.setPath.enable = true;
      };

      modules.services.greetd.sessionDirs = [
        "${hyprlandPackage}/share/wayland-sessions"
      ];
    })

    (mkIf (windowManager == "sway") {
      programs.sway.enable = true;
    })
  ]);
}
