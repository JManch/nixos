{ lib, inputs, ... }:
let
  inherit (lib) optionalAttrs;
  vmInstall = inputs.vmInstall.value;
in
{
  imports = [
    inputs.disko.nixosModules.default
  ];

  disko.devices = {
    disk."512GB-SATA" = {
      type = "disk";
      # WARN: If installing in a VM use /dev/disk/by-path/ and enable the
      # modules.fileSystem.zfsVM option
      device =
        if vmInstall then
          "/dev/disk/by-path/pci-0000:04:00.0"
        else
        # TODO: Set this
          "/dev/disk/by-path/pci-0000:04:00.0";
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

    zpool.zroot = {
      type = "zpool";
      options.ashift = "12";

      rootFsOptions = {
        atime = "off";
        mountpoint = "none";
        xattr = "sa";
        acltype = "posixacl";
        compression = "lz4";
      } // optionalAttrs (!vmInstall) {
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
