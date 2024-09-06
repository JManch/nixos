{
  ns,
  lib,
  config,
  username,
  ...
}:
let
  inherit (lib) mkIf;
  inherit (homeConfig.programs) swaylock hyprlock;
  inherit (config.${ns}.core) homeManager;
  homeConfig = config.home-manager.users.${username};
in
{
  # Show asterisks when typing sudo password
  security.sudo.extraConfig = "Defaults pwfeedback";

  security.pam.services = mkIf (homeManager.enable) {
    swaylock = mkIf swaylock.enable { };
    hyprlock = mkIf hyprlock.enable { };
  };
}
