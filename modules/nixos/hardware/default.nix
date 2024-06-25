{ lib, ... }:
let
  inherit (lib) utils mkOption mkEnableOption types mkDefault;
in
{
  imports = utils.scanPaths ./.;

  options.modules.hardware = {
    vr.enable = mkEnableOption "virtual reality";
    secureBoot.enable = mkEnableOption "secure boot";
    fanatec.enable = mkEnableOption "support for Fanatec hardware";

    fileSystem = {
      trim = mkEnableOption "ZFS automatic trimming";
      unstableZfs = mkEnableOption "unstable ZFS";
      tmpfsTmp = mkEnableOption "tmp on tmpfs";

      extendedLoaderTimeout = mkEnableOption ''
        an extended loader timeout of 30 seconds. Useful for switching to old
        generations on headless machines.
      '';
    };

    printing = {
      server.enable = mkEnableOption "printing server";

      client = {
        enable = mkEnableOption "printing client";
        serverAddress = mkOption {
          type = types.str;
          description = "Address of the cups server to print from";
        };
      };
    };
  };

  config = {
    # Replaces the (modulesPath + "/installer/scan/not-detected.nix") import
    hardware.enableRedistributableFirmware = mkDefault true;
  };
}
