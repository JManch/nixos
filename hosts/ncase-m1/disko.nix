{ inputs, ... }:
{
  imports = [
    inputs.disko.nixosModules.default
  ];

  disko.devices = {
    disk."1TB-NVME" = {
      type = "disk";
      device = "/dev/disk/by-id/nvme-Samsung_SSD_970_EVO_Plus_1TB_S4EWNM0W333051B";
      content = {
        type = "gpt";
        partitions = {
          esp = {
            name = "boot";
            # TODO: Delete this next install. Disko will use partlabel from
            # disk attribute name instead.
            device = "/dev/disk/by-label/boot";
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
              # TODO: Change this to zroot next install
              pool = "zpool";
            };
          };
        };
      };
    };

    nodev."/" = {
      fsType = "tmpfs";
      mountOptions = [ "defaults" "mode=755" ];
    };

    # TODO: Next install change zpool name to zroot to match homelab disko
    zpool.zpool = {
      type = "zpool";

      rootFsOptions = {
        atime = "off";
        mountpoint = "none";
        xattr = "sa";
        acltype = "posixacl";
        encryption = "aes-256-gcm";
        keyformat = "passphrase";
        keylocation = "prompt";
        compression = "lz4";
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
      };
    };
  };
}
