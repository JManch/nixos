# I use this module with the Coral M.2 accelerator and it works perfectly in
# Frigate. In theory it should also work with the USB accelerator. I packaged
# libedgetpu following the instructions here:
# https://github.com/NixOS/nixpkgs/issues/188719#issuecomment-2094575860
{
  ns,
  lib,
  pkgs,
  config,
  inputs,
  ...
}:
let
  inherit (lib)
    mkIf
    listToAttrs
    optional
    singleton
    ;
  cfg = config.${ns}.hardware.coral;
  libedgetpu = config.boot.kernelPackages.callPackage "${inputs.nix-resources}/pkgs/libedgetpu" { };
  gasket = config.boot.kernelPackages.gasket.overrideAttrs {
    src = pkgs.fetchFromGitHub {
      owner = "google";
      repo = "gasket-driver";
      rev = "5815ee3908a46a415aac616ac7b9aedcb98a504c";
      sha256 = "sha256-O17+msok1fY5tdX1DvqYVw6plkUDF25i8sqwd6mxYf8=";
    };
  };
  isPci = cfg.type == "pci";
in
mkIf cfg.enable {
  boot.extraModulePackages = optional isPci gasket;

  users.groups = listToAttrs (singleton {
    name = if isPci then "apex" else "plugdev";
    value = { };
  });

  services.udev = {
    packages = optional (!isPci) libedgetpu;
    extraRules = mkIf isPci ''
      SUBSYSTEM=="apex", MODE="0660", GROUP="apex"
    '';
  };

  systemd.services.frigate = {
    serviceConfig.SupplementaryGroups = [ (if isPci then "apex" else "plugdev") ];

    environment.LD_LIBRARY_PATH = lib.makeLibraryPath [
      libedgetpu
      # Even though this is technically not needed for pci version, Frigate
      # throws an error without it
      pkgs.libusb
    ];
  };

  services.frigate.settings.detectors.coral = {
    type = "edgetpu";
  };
}
