{ inputs, ... }:
{
  imports = [
    inputs.disko.nixosModules.default
  ];

  disko.devices = {
    # The attribute name of the disk gets used for the disk partlabel
    disk."256GB-NVME" = {
      type = "disk";
      device = "/dev/disk/by-id/nvme-SAMSUNG_MZVPV256HDGL-000H1_S27GNY0HB13473";
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
      options.ashift = "12";

      # rootFsOptions are -O options and options are -o
      rootFsOptions = {
        atime = "off";
        mountpoint = "none";
        xattr = "sa";
        acltype = "posixacl";
        compression = "lz4";
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
}
