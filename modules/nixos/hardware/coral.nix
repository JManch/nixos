# I use this module with the Coral M.2 accelerator and it works perfectly in
# Frigate. In theory it should also work with the USB accelerator.
{
  ns,
  lib,
  pkgs,
  config,
  ...
}:
let
  inherit (lib)
    mkIf
    listToAttrs
    optional
    singleton
    makeLibraryPath
    ;
  cfg = config.${ns}.hardware.coral;
  isPci = cfg.type == "pci";
in
mkIf cfg.enable {
  boot.extraModulePackages = optional isPci config.boot.kernelPackages.gasket;

  users.groups = listToAttrs (singleton {
    name = if isPci then "apex" else "plugdev";
    value = { };
  });

  services.udev = {
    packages = optional (!isPci) pkgs.libedgetpu;
    extraRules = mkIf isPci ''
      SUBSYSTEM=="apex", MODE="0660", GROUP="apex"
    '';
  };

  systemd.services.frigate = {
    serviceConfig.SupplementaryGroups = [ (if isPci then "apex" else "plugdev") ];

    environment.LD_LIBRARY_PATH = makeLibraryPath [
      pkgs.libedgetpu
      # Even though this is technically not needed for pci version, Frigate
      # throws an error without it
      pkgs.libusb1
    ];
  };

  services.frigate.settings.detectors.coral = {
    type = "edgetpu";
  };
}
