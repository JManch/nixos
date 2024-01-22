{ lib
, config
, inputs
, ...
} @ args:
let
  inherit (lib) mkIf mkMerge;
  desktopCfg = config.usrEnv.desktop;
  desktopEnvironment = desktopCfg.desktopEnvironment;
  homeConfig = lib.utils.homeConfig args;
  homeDesktopCfg = homeConfig.modules.desktop;
  windowManager = homeConfig.modules.desktop.windowManager;
  isWayland = lib.fetchers.isWayland homeConfig;
in
{
  imports = [
    inputs.hyprland.nixosModules.default
  ];

  # TODO: Improve the isWayland function to take desktopEnvironment into account
  # TODO: 
  config = mkIf config.usrEnv.desktop.enable (mkMerge [
    {
      services.xserver.layout = "us";

      # Needed for swaylock authentication
      security.pam.services.swaylock = mkIf (isWayland && homeDesktopCfg.swaylock.enable) { };

      # We configure xdg portal in home-manager
      # TODO: Configure xdg portal in home-manager for each of these desktopEnvironments
      xdg.portal.enable = lib.mkForce false;
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

    (mkIf (windowManager == "hyprland") {
      programs.hyprland.enable = true;
    })

    (mkIf (windowManager == "sway") {
      programs.sway.enable = true;
    })
  ]
  );
}
