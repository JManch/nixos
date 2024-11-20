{ inputs, ... }:
{
  imports = [ inputs.disko.nixosModules.default ];

  disko.devices = {
    # The attribute name of the disk gets used for the disk partlabel
    disk."1TB-SSD" = {
      type = "disk";
      device =
        if inputs.vmInstall.value then
          "/dev/disk/by-path/pci-0000:04:00.0"
        else
          # "/dev/disk/by-id/nvme-SAMSUNG_MZVPV256HDGL-000H1_S27GNY0HB13473";
          "/dev/disk/by-id/ata-CT1000MX500SSD1_1923E209C93E";
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
              pool = "homelab-zpool";
            };
          };
        };
      };
    };

    nodev."/" = {
      fsType = "tmpfs";
      mountOptions = [
        "defaults"
        "mode=755"
      ];
    };

    zpool.homelab-zpool = {
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
        homelab-nixos.type = "zfs_fs";

        "homelab-nixos/nix" = {
          type = "zfs_fs";
          mountpoint = "/nix";
          options.mountpoint = "legacy";
        };

        "homelab-nixos/persist" = {
          type = "zfs_fs";
          mountpoint = "/persist";
          options = {
            mountpoint = "legacy";
            encryption = "aes-256-gcm";
            keyformat = "passphrase";
            keylocation = "prompt";
          };
        };

        "homelab-nixos/persist/tmp" = {
          type = "zfs_fs";
          mountpoint = "/tmp";
          options.mountpoint = "legacy";
        };

        "homelab-nixos/persist/media" = {
          type = "zfs_fs";
          mountpoint = "/persist/media";
          options.mountpoint = "legacy";
          options.recordsize = "1M";
        };

        "homelab-nixos/persist/postgresql" = {
          type = "zfs_fs";
          mountpoint = "/persist/var/lib/postgresql";
          options.mountpoint = "legacy";
          options.recordsize = "8k";
        };

        "homelab-nixos/persist/srv" = {
          type = "zfs_fs";
          mountpoint = "/persist/srv";
          options.mountpoint = "legacy";
          options.recordsize = "1M";
        };
      };
    };
  };

  # WARN: If a mountpoint is a subdir of an impermanence bind mount, it must be
  # ordered after the impermanance bind mount as impermanence does not use
  # rbind. An example from an old mountpoint I no longer use:

  # fileSystems = {
  #   "/persist/var/lib/qbittorrent-nox/qBittorrent/downloads".depends = [ "/var/lib/qbittorrent-nox" ];
  #   "/persist/var/lib/qbittorrent-nox/qBittorrent/downloads-tmp".depends = [
  #     "/var/lib/qbittorrent-nox"
  #   ];
  # };
}
