{
  lib,
  pkgs,
  config,
  categoryCfg,
}:
let
  inherit (lib) ns mkIf mkDefault;
  inherit (config.${ns}.core) home-manager;
in
{
  enableOpt = false;
  conditions = [ (categoryCfg.desktopEnvironment == "plasma") ];

  services.desktopManager.plasma6.enable = true;

  services.displayManager.plasma-login-manager.enable = true;

  environment.plasma6.excludePackages = with pkgs.kdePackages; [
    kwin-x11
    elisa # music player
  ];

  ns.hm = mkIf home-manager.enable {
    ${ns}.desktop.terminal = mkDefault "org.kde.konsole";
  };
}
