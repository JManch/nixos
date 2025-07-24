{ lib, inputs, ... }:
let
  vmInstall = inputs.vmInstall.value;
in
{
  imports = [ inputs.disko.nixosModules.default ];

  disko.devices = {
    disk."256GB-SATA" = {
      type = "disk";
      device =
        if vmInstall then
          "/dev/disk/by-path/pci-0000:04:00.0"
        else
          "/dev/disk/by-id/ata-Crucial_CT275MX300SSD1_163313B135A9";
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
              mountOptions = [
                "defaults"
                "umask=0077"
              ];
            };
          };
          zfs = {
            size = "100%";
            content = {
              type = "zfs";
              pool = "msi-zroot";
            };
          };
        };
      };
    };

    zpool.msi-zroot = {
      type = "zpool";
      options.ashift = "12";

      rootFsOptions = {
        atime = "off";
        mountpoint = "none";
        xattr = "sa";
        acltype = "posixacl";
        compression = "lz4";
      }
      // lib.optionalAttrs (!vmInstall) {
        encryption = "aes-256-gcm";
        keyformat = "passphrase";
        keylocation = "prompt";
      };

      datasets.root = {
        type = "zfs_fs";
        mountpoint = "/";
        options.mountpoint = "legacy";
      };
    };
  };
}
