{ inputs, ... }:
{
  imports = [
    inputs.disko.nixosModules.default
  ];

  disko.devices = {
    disk."256GB-NVME" = {
      type = "disk";
      # TODO: Change this device
      device = "/dev/vda";
      content = {
        type = "gpt";
        partitions = {
          esp = {
            name = "boot";
            size = "512M";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [ "defaults" "umask=0077" ];
            };
          };
          zfs = {
            size = "100%";
            content = {
              type = "zfs";
              pool = "zroot";
            };
          };
        };
      };
    };

    nodev."/" = {
      fsType = "tmpfs";
      mountOptions = [ "defaults" "mode=755" ];
    };

    zpool.zroot = {
      type = "zpool";

      rootFsOptions = {
        # TODO: Double check these options
        atime = "off";
        mountpoint = "none";
        xattr = "sa";
        acltype = "posixacl";
        compression = "lz4";
        # TODO: Look into this
        # "com.sun:auto-snapshot" = "true";
      };

      options = {
        ashift = "12";
      };

      datasets = {
        nix = {
          type = "zfs_fs";
          mountpoint = "/nix";
          options.mountpoint = "legacy";
        };

        persist = {
          type = "zfs_fs";
          mountpoint = "/persist";
          options.mountpoint = "legacy";
        };

        tmp = {
          type = "zfs_fs";
          mountpoint = "/tmp";
          options.mountpoint = "legacy";
        };
      };
    };
  };

  # TODO: These needs to be reworked. Need an option for the persist dir
  fileSystems."/persist".neededForBoot = true;
}
