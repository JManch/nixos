{ lib
, pkgs
, config
, inputs
, username
, ...
}:
let
  inherit (lib) mkIf utils types mkEnableOption mkOption elem;
  inherit (config.modules.core) homeManager;
  inherit (config.device) gpu;
  inherit (config.modules.system.desktop) isWayland;
  cfg = config.modules.system.desktop;
in
{
  imports = (utils.scanPaths ./.) ++ [
    inputs.hyprland.nixosModules.default
  ];

  options.modules.system.desktop = {
    enable = mkEnableOption "desktop functionality";

    desktopEnvironment = mkOption {
      type = with types; nullOr (enum [ "xfce" "plasma" "gnome" ]);
      default = null;
      description = ''
        The desktop environment to use. The window manager is configured in
        home manager. Some windows managers don't require a desktop
        environment and some desktop environments include a window manager.
      '';
    };

    isWayland = mkOption {
      type = types.bool;
      readOnly = true;
      default = (if config.modules.core.homeManager.enable then
        (elem config.home-manager.users.${username}.modules.desktop.windowManager utils.waylandWindowManagers)
      else
        false) ||
      (elem cfg.desktopEnvironment utils.waylandDesktopEnvironments);
    };
  };


  config = mkIf cfg.enable {
    i18n.defaultLocale = "en_GB.UTF-8";
    services.xserver.excludePackages = [ pkgs.xterm ];

    # Enables wayland for all apps that support it
    environment.sessionVariables.NIXOS_OZONE_WL = mkIf isWayland "1";

    # To workaround Nvidia explicit sync crashing, temporarily force Firefox
    # to use xwayland. Remove once this issue gets resolved:
    # https://bugzilla.mozilla.org/show_bug.cgi?id=1898476
    environment.sessionVariables.MOZ_ENABLE_WAYLAND = mkIf (gpu.type == "nvidia") 0;

    # Necessary for xdg-portal home-manager module to work with useUserPackages enabled
    # https://github.com/nix-community/home-manager/pull/5184
    # NOTE: When https://github.com/nix-community/home-manager/pull/2548 gets
    # merged this may no longer be needed
    environment.pathsToLink = mkIf homeManager.enable
      [ "/share/xdg-desktop-portal" "/share/applications" ];
  };
}
