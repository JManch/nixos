{ lib, config, ... }:
let
  inherit (lib) ns mkIf;
  inherit (config.hm.programs) swaylock hyprlock;
  inherit (config.${ns}.core) homeManager;
in
{
  security.sudo.extraConfig = ''
    Defaults lecture=never
    Defaults pwfeedback
  '';

  security.pam.services = mkIf (homeManager.enable) {
    swaylock = mkIf swaylock.enable { };
    hyprlock = mkIf hyprlock.enable { };
  };
}
