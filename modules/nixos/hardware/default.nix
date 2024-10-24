{
  ns,
  lib,
  config,
  hostname,
  ...
}:
let
  inherit (lib)
    mkOption
    mkEnableOption
    types
    mkDefault
    attrValues
    any
    mapAttrsToList
    hasAttr
    hasPrefix
    literalExpression
    ;
  cfg = config.${ns}.hardware;
in
{
  imports = lib.${ns}.scanPathsExcept ./. [ "raspberry-pi.nix" ];

  options.${ns}.hardware = {
    vr.enable = mkEnableOption "virtual reality";
    secureBoot.enable = mkEnableOption "secure boot";
    fanatec.enable = mkEnableOption "support for Fanatec hardware";

    raspberryPi = {
      enable = mkOption {
        type = types.bool;
        readOnly = true;
        default = hasPrefix "pi" hostname;
        description = "Whether this host is a raspberry pi";
      };

      uboot = {
        enable = mkEnableOption "uboot bootloader (disable on newer pis)" // {
          default = null;
        };

        package = mkOption {
          type = types.package;
          example = literalExpression "pkgs.ubootRaspberryPi3_64bit";
          description = ''
            The uboot package to use. The overlay raspberry-pi-nix uses breaks
            things so we replace it.
          '';
        };
      };
    };

    fileSystem = {
      tmpfsTmp = mkEnableOption "tmp on tmpfs";
      extendedLoaderTimeout = mkEnableOption ''
        an extended loader timeout of 30 seconds. Useful for switching to old
        generations on headless machines.
      '';

      type = mkOption {
        type = types.enum [
          "zfs"
          "ext4"
          "sd-image"
        ];
        default = null;
        description = "The type of filesystem on this host";
      };

      zfs = {
        unstable = mkEnableOption "unstable ZFS";
        trim = mkEnableOption "ZFS automatic trimming";

        encryption = {
          enable = mkOption {
            type = types.bool;
            readOnly = true;
            # Check for any pool datasets with encryption enable or child
            # datasets with encryption enabled
            default = lib.any (v: v == true) (
              mapAttrsToList (
                _: pool:
                (hasAttr "encryption" pool.rootFsOptions)
                || (any (dataset: hasAttr "encryption" dataset.options) (attrValues pool.datasets))
              ) config.disko.devices.zpool
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
          inherit (config.${ns}.device) memory;
        in
        {
          enable = mkEnableOption "swap" // {
            default = cfg.fileSystem.type != "zfs" && cfg.fileSystem.type != "sd-image" && memory <= 4 * 1024;
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
