{
  lib,
  pkgs,
  config,
  username,
  categoryCfg,
  adminUsername,
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

  # KDE GUI prompts for root password sometimes. Ideally it would prompt for
  # sudo on our admin user but I don't see an easy way to do that so this
  # works.
  users.users."root" = mkIf (username != adminUsername) {
    hashedPasswordFile = config.age.secrets."${adminUsername}Passwd".path;
  };

  ns.hm = mkIf home-manager.enable {
    ${ns}.desktop.terminal = mkDefault "org.kde.konsole";
  };
}
