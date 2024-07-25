{ lib, config, ... }:
let
  inherit (lib)
    utils
    mkOption
    mkEnableOption
    types
    mkDefault
    mapAttrsToList
    hasAttr
    ;
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

      encrypted = mkOption {
        type = types.bool;
        readOnly = true;
        default = lib.any (v: v == true) (
          mapAttrsToList (_: pool: hasAttr "encryption" pool.rootFsOptions) config.disko.devices.zpool
        );
        description = ''
          Whether the file system uses disk encryption. Derived from disko
          config.
        '';
      };

      zfsPassphraseCred = mkOption {
        type = with types; nullOr lines;
        default = null;
        description = ''
          Encrypted ZFS passphrase credential generated with
          `systemd-ask-password -n | systemd-creds encrypt --with-key=tpm2
          --name=zfs-passphrase -p - -`
        '';
      };
    };

    coral = {
      enable = mkEnableOption "Google Coral TPU";
      type = mkOption {
        type = types.enum [
          "pci"
          "usb"
        ];
        description = "Connection type of Google Coral TPU";
      };
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
