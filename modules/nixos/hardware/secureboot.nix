{ lib
, pkgs
, config
, inputs
, ...
}:
let
  inherit (lib) mkIf mkForce;
  cfg = config.modules.hardware.secureBoot;
in
{
  # Requires manual initial setup
  # https://github.com/nix-community/lanzaboote/blob/master/docs/QUICK_START.md
  imports = [
    inputs.lanzaboote.nixosModules.lanzaboote
  ];

  # Secure boot is disabled for the very first build of a newly installed
  # system so that I can set it up
  config = mkIf (!inputs.firstBoot.value && cfg.enable) {
    environment.systemPackages = [ pkgs.sbctl ];

    # NOTE: Lanzaboote replaces systemd-boot with it's own systemd-boot which
    # is configured here. Lanzaboote inherits most config from the standard
    # systemd-boot configuration.
    boot.loader.systemd-boot.enable = mkForce false;
    boot.lanzaboote = {
      enable = true;
      pkiBundle = "/persist/etc/secureboot";
    };

    persistence.directories = [ "/etc/secureboot" ];
  };
}
