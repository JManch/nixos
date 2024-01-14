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
  desktopManager = desktopCfg.desktopManager;
in
lib.mkIf config.usrEnv.desktop.enable {
  services.xserver = lib.mkMerge [
    {
      # Enable regardless of wayland for xwayland support
      enable = true;
      layout = "us";
      # Disable default login GUI if we're using wayland
      displayManager.lightdm.enable = !lib.fetchers.isWayland homeManagerConfig;
    }

    (lib.mkIf (desktopManager == "plasma") {
      displayManager = {
        defaultSession = "plasma";
        sddm.enable = true;
      };
      desktopManager = {
        plasma5.enable = true;
      };
    })

    (lib.mkIf (desktopManager == "xfce") {
      displayManager.defaultSession = "xfce";
      desktopManager = {
        xterm.enable = false;
        xfce = {
          enable = true;
          noDesktop = !desktopCfg.desktopManagerWindowManager;
        };
      };
    })
  ];

  programs = {
    dconf.enable = true;
    xwayland.enable = true;
  };
  security.polkit.enable = true;

  fonts.enableDefaultPackages = true;

  # Needed for swaylock authentication
  security.pam.services.swaylock = lib.mkIf (homeManagerConfig.modules.desktop.swaylock.enable) { };
}
