{
  lib,
  config,
  hostname,
  ...
}:
let
  inherit (lib)
    ns
    mkOption
    mkEnableOption
    types
    mkDefault
    attrValues
    any
    mapAttrsToList
    hasAttr
    hasPrefix
    removeAttrs
    literalExpression
    ;
  cfg = config.${ns}.hardware;
in
{
  imports = lib.${ns}.scanPathsExcept ./. [
    "raspberry-pi.nix"
    "nix-on-droid.nix"
  ];

  options.${ns}.hardware = {
    bluetooth.enable = mkEnableOption "bluetooth";
    secureBoot.enable = mkEnableOption "secure boot";
    fanatec.enable = mkEnableOption "support for Fanatec hardware";
    tablet.enable = mkEnableOption "OpenTabletDriver";

    valve-index = {
      enable = mkEnableOption "virtual reality";

      audio = {
        card = mkOption {
          type = types.str;
          description = "Name of the Index audio card from `pact list cards`";
        };

        profile = mkOption {
          type = types.str;
          description = "Name of the Index audio profile from `pactl list cards`";
        };

        source = mkOption {
          type = types.str;
          description = "Name of the Index source device from `pactl list short sources`";
        };

        sink = mkOption {
          type = types.str;
          description = "Name of the Index sink device from `pactl list short sinks`";
        };
      };
    };

    raspberryPi = {
      enable = mkOption {
        type = types.bool;
        readOnly = true;
        default = hasPrefix "pi" hostname;
        description = "Whether this host is a raspberry pi";
      };

      uboot = {
        enable = removeAttrs (mkEnableOption "uboot bootloader (disable on newer pis)") [ "default" ];

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

      ext4.trim = removeAttrs (mkEnableOption "ext4 automatic trimming") [ "default" ];

      zfs = {
        unstable = mkEnableOption "unstable ZFS";
        trim = removeAttrs (mkEnableOption "ZFS automatic trimming") [ "default" ];

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
            description = "Size of swap file in megabytes";
          };
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

    keyd = {
      enable = mkEnableOption "keyd";
      swapCapsControl = mkEnableOption "swapping caps lock and left control";
      swapAltMeta = mkEnableOption "swapping left alt and left meta";

      excludedDevices = mkOption {
        type = with types; listOf str;
        default = [ ];
        example = [ "04fe:0021:5b3ab73a" ];
        description = "List of devices to exclude from keyd";
      };
    };
  };

  config = {
    # Replaces the (modulesPath + "/installer/scan/not-detected.nix") import
    hardware.enableRedistributableFirmware = mkDefault true;
  };
}
