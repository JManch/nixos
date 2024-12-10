{
  lib,
  pkgs,
  config,
  inputs,
  ...
}:
let
  inherit (lib)
    ns
    mkIf
    mkForce
    optionalString
    ;
  inherit (config.${ns}.system) impermanence;
  cfg = config.${ns}.hardware.secureBoot;
in
{
  # Requires manual initial setup
  # https://github.com/nix-community/lanzaboote/blob/master/docs/QUICK_START.md
  imports = [ inputs.lanzaboote.nixosModules.lanzaboote ];

  # New install setup process:
  # Boot 1: Bios secure boot is disabled; Lanzaboote is enabled. Secure
  #         boot keys have already been generated in install script. Run `sbctl
  #         verify` to ensure EFI files have been signed. If not, reboot.
  # Boot into bios: Enable secure boot in "Setup Mode".
  # Boot 2: Enroll our keys as instructed in the docs.
  # Done

  config = mkIf cfg.enable {
    adminPackages = [ pkgs.sbctl ];

    # NOTE: Lanzaboote replaces systemd-boot with it's own systemd-boot which
    # is configured here. Lanzaboote inherits most config from the standard
    # systemd-boot configuration.
    boot.loader.systemd-boot.enable = mkForce false;

    boot.lanzaboote = {
      enable = true;
      pkiBundle = "${optionalString impermanence.enable "/persist"}/etc/secureboot";
    };

    persistence.directories = [ "/etc/secureboot" ];
  };
}
