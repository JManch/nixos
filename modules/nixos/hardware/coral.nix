{
  lib,
  pkgs,
  config,
  inputs,
  ...
}:
let
  cfg = config.modules.hardware.coral;
  libedgetpu = config.boot.kernelPackages.callPackage "${inputs.nix-resources}/pkgs/libedgetpu" { };
  gasket = config.boot.kernelPackages.gasket.overrideAttrs {
    src = pkgs.fetchFromGitHub {
      owner = "google";
      repo = "gasket-driver";
      rev = "5815ee3908a46a415aac616ac7b9aedcb98a504c";
      sha256 = "sha256-O17+msok1fY5tdX1DvqYVw6plkUDF25i8sqwd6mxYf8=";
    };
  };
in
lib.mkIf cfg.enable {
  services.udev.packages = [ libedgetpu ];
  boot.extraModulePackages = [ gasket ];
  users.groups.plugdev = { };

  systemd.services.frigate = {
    serviceConfig.SupplementaryGroups = "plugdev";
    environment.LD_LIBRARY_PATH = lib.makeLibraryPath [ libedgetpu ];
  };
}
