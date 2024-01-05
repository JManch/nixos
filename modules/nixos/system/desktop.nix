{ lib
, config
, outputs
, hostname
, username
, ...
}:
let
  homeManagerConfig = outputs.nixosConfigurations.${hostname}.config.home-manager.users.${username};
  desktopCfg = config.usrEnv.desktop;
in
lib.mkIf config.usrEnv.desktop.enable {
  # TODO: I think it would be a good idea to split this file up into multiple
  # nix files for each desktop manager, just to make things cleaner
  services.xserver = {
    # Enable regardless of wayland for xwayland support
    enable = true;

    displayManager = {
      defaultSession = lib.mkIf (desktopCfg.desktopManager != null) desktopCfg.desktopManager;

      # Disable default login GUI if we're using wayland
      lightdm.enable = !lib.fetchers.isWayland homeManagerConfig;
      sddm.enable = desktopCfg.desktopManager == "plasma";
    };

    desktopManager = {
      xfce = {
        enable = desktopCfg.desktopManager == "xfce";
        noDesktop = !desktopCfg.desktopManagerWindowManager;
      };
      # KDE Plasma5
      plasma5.enable = desktopCfg.desktopManager == "plasma";
    };
  };

  programs.dconf.enable = true;
  security.polkit.enable = true;

  # Needed for swaylock authentication
  security.pam.services.swaylock = lib.mkIf (homeManagerConfig.modules.desktop.swaylock.enable) { };
}
