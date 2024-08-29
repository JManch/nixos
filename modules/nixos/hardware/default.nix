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
  cfg = config.modules.hardware;
in
{
  imports = utils.scanPaths ./.;

  options.modules.hardware = {
    vr.enable = mkEnableOption "virtual reality";
    secureBoot.enable = mkEnableOption "secure boot";
    fanatec.enable = mkEnableOption "support for Fanatec hardware";

    fileSystem = {
      tmpfsTmp = mkEnableOption "tmp on tmpfs";
      extendedLoaderTimeout = mkEnableOption ''
        an extended loader timeout of 30 seconds. Useful for switching to old
        generations on headless machines.
      '';

      type = mkOption {
        type = types.enum [
          "zfs"
          "sdImage"
        ];
        default = null;
        description = ''
          The type of filesystem on this host. Should be `sdImage` if the host
          is installed using the sd-image.nix installer. In this case, the
          system uses a ext4 root filesystem labelled NIXOS_SD.
        '';
      };

      zfs = {
        unstable = mkEnableOption "unstable ZFS";
        trim = mkEnableOption "ZFS automatic trimming";

        encryption = {
          enable = mkOption {
            type = types.bool;
            readOnly = true;
            default = lib.any (v: v == true) (
              mapAttrsToList (_: pool: hasAttr "encryption" pool.rootFsOptions) config.disko.devices.zpool
            );
            description = ''
              Whether the file system uses ZFS disk encryption. Derived from disko
              config.
            '';
          };

          passphraseCred = mkOption {
            type = with types; nullOr lines;
            default = null;
            description = ''
              Encrypted ZFS passphrase credential generated with
              `systemd-ask-password -n | systemd-creds encrypt --with-key=tpm2
              --name=zfs-passphrase -p - -`
            '';
          };
        };
      };

      swap =
        let
          inherit (config.device) memory;
        in
        {
          enable = mkEnableOption "swap" // {
            default = cfg.fileSystem.type != "zfs" && cfg.fileSystem.type != "sdImage" && memory <= 4 * 1024;
          };

          size = mkOption {
            type = types.int;
            default =
              if memory <= 2 * 1024 then
                memory * 2
              else if memory <= 8 * 1024 then
                memory
              else
                1024 * 4;
            description = "Size of swap partition in megabytes";
          };
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
