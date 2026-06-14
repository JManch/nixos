{ lib, config }:
let
  inherit (lib) ns mkIf;
  inherit (config.${ns}.hmNs.desktop) locker;
  inherit (config.${ns}.hm.programs) hyprlock;
  inherit (config.${ns}.core) home-manager;
in
{
  enableOpt = false;

  security.sudo.extraConfig = ''
    Defaults lecture=never
    Defaults pwfeedback
  '';

  security.pam.services = mkIf (home-manager.enable) {
    swaylock = mkIf (locker == "swaylock") { };
    hyprlock = mkIf (locker == "hyprlock" && hyprlock.settings.auth.pam.enabled) {
      fprintAuth = false; # prefer native hyprlock fingerprint support https://github.com/hyprwm/hyprlock/pull/1026
    };
    waylock = mkIf (locker == "waylock") { };
  };
}
