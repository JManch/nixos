{
  disko.devices = {
    # WARN: Should probably update this name 'x' to something like 1TB-NVME
    disk.disk1 = {
      type = "disk";
      # WARN:The device here actually has to be correct
      device = "/dev/sdx";
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
            };
          };
          zfs = {
            size = "100%";
            # WARN: I feel like I need more here for configuring the zpool?
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
      mode = "";
      rootFsOptions = {
        # WARN: I don't know if any of these options are correct really...
        ashift = 12;
        atime = "off";
        mountpoint = "none";
        xattr = "sa";
        acltype = "posixacl";
        compression = "lz4"; # double check this
      };
      # WARN: I don't understand this mountpoint here?
      mountpoint = "/";
      postCreateHook = "zfs snapshot zroot@blank";

      datasets = {
        nix = {
          type = "zfs_fs";
          options.mountpoint = "legacy";
          mountpoint = "/nix";
        };

        persist = {
          type = "zfs_fs";
          options.mountpoint = "legacy";
          mountpoint = "/persist";
        };

        tmp = {
          type = "zfs_fs";
          options.mountpoint = "legacy";
          mountpoint = "/tmp";
        };
      };
    };
  };
}
