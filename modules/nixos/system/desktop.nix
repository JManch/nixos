{ lib, config, inputs, ... } @ args:
let
  inherit (lib) mkIf mkMerge fetchers utils mkForce;
  inherit (desktopCfg) desktopEnvironment;
  inherit (homeDesktopCfg) windowManager;
  desktopCfg = config.usrEnv.desktop;
  homeConfig = utils.homeConfig args;
  homeDesktopCfg = homeConfig.modules.desktop;
  isWayland = fetchers.isWayland homeConfig;
in
{
  imports = [
    inputs.hyprland.nixosModules.default
  ];

  # TODO: Improve the isWayland function to take desktopEnvironment into account
  config = mkIf config.usrEnv.desktop.enable (mkMerge [
    {
      services.xserver.xkb.layout = "us";

      # Needed for swaylock authentication
      security.pam.services.swaylock = mkIf (isWayland && homeDesktopCfg.programs.swaylock.enable) { };
      security.pam.services.hyprlock = mkIf (isWayland && homeDesktopCfg.programs.hyprlock.enable) { };

      # We configure xdg portal in home-manager
      # TODO: Configure xdg portal in home-manager for each of these desktopEnvironments
      xdg.portal.enable = mkForce false;
    }

    (mkIf (desktopEnvironment == "xfce") {
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

    (mkIf (desktopEnvironment == "plasma") {
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

    (mkIf (desktopEnvironment == "gnome") {
      services.xserver = {
        enable = true;
        displayManager.gdm.enable = true;
        desktopManager.gnome.enable = true;
      };
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
      programs.hyprland.enable = true;
    })

    (mkIf (windowManager == "sway") {
      programs.sway.enable = true;
    })
  ]);
}
