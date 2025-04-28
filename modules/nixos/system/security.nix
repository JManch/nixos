{ lib, config }:
let
  inherit (lib) ns mkIf;
  inherit (config.${ns}.hm.programs) swaylock hyprlock;
  inherit (config.${ns}.core) home-manager;
in
{
  enableOpt = false;

  security.sudo.extraConfig = ''
    Defaults lecture=never
    Defaults pwfeedback
  '';

  security.pam.services = mkIf (home-manager.enable) {
    swaylock = mkIf swaylock.enable { };
    hyprlock = mkIf (hyprlock.enable && hyprlock.settings.auth.pam.enabled) { };
  };
}
