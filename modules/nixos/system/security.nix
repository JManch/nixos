{
  ns,
  lib,
  config,
  ...
}:
let
  inherit (lib) mkIf;
  inherit (config.hm.programs) swaylock hyprlock;
  inherit (config.${ns}.core) homeManager;
in
{
  # Show asterisks when typing sudo password
  security.sudo.extraConfig = "Defaults pwfeedback";

  security.pam.services = mkIf (homeManager.enable) {
    swaylock = mkIf swaylock.enable { };
    hyprlock = mkIf hyprlock.enable { };
  };
}
