{
  lib,
  inputs,
  username,
  hostname,
  ...
}:
let
  inherit (lib) optionalAttrs;
  vmInstall = inputs.vmInstall.value;
  poolName = "${hostname}-zpool";
  pseudoRoot = "${hostname}-nixos";
in
{
  imports = [ inputs.disko.nixosModules.default ];

  disko.devices = {
    disk = {
      "1TB-NVME-SABRENT" = {
        type = "disk";
        device =
          if vmInstall then
            "/dev/disk/by-path/pci-0000:04:00.0"
          else
            "/dev/disk/by-id/nvme-Sabrent_Rocket_4.0_1TB_CD8E079C1B9E01168005";
        content = {
          type = "gpt";
          partitions = {
            esp = {
              name = "boot";
              size = "1024M";
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
                pool = poolName;
              };
            };
          };
        };
      };

      "1TB-NVME-SAMSUNG" = {
        type = "disk";
        device =
          if vmInstall then
            "/dev/disk/by-path/pci-0000:08:00.0"
          else
            "/dev/disk/by-id/nvme-Samsung_SSD_970_EVO_Plus_1TB_S4EWNM0W333051B";
        content = {
          type = "gpt";
          partitions.zfs = {
            size = "100%";
            content = {
              type = "zfs";
              pool = "${poolName}-1";
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

    zpool =
      let
        rootFsOptions = {
          atime = "off";
          mountpoint = "none";
          xattr = "sa";
          acltype = "posixacl";
          compression = "lz4";
        };
      in
      {
        ${poolName} = {
          type = "zpool";
          options.ashift = "12";
          inherit rootFsOptions;

          datasets = {
            ${pseudoRoot}.type = "zfs_fs";

            "${pseudoRoot}/nix" = {
              type = "zfs_fs";
              mountpoint = "/nix";
              options.mountpoint = "legacy";
            };

            "${pseudoRoot}/persist" = {
              type = "zfs_fs";
              options = optionalAttrs (!vmInstall) {
                encryption = "aes-256-gcm";
                keyformat = "passphrase";
                keylocation = "prompt";
              };
            };

            "${pseudoRoot}/persist/steam" = {
              type = "zfs_fs";
              mountpoint = "/persist/home/${username}/.local/share/Steam";
              options.mountpoint = "legacy";
              options.recordsize = "1M";
            };

            "${pseudoRoot}/persist/games" = {
              type = "zfs_fs";
              mountpoint = "/persist/home/${username}/games";
              options.mountpoint = "legacy";
              options.recordsize = "1M";
            };

            "${pseudoRoot}/persist/models" = {
              type = "zfs_fs";
              mountpoint = "/persist/var/lib/private/ollama";
              options.mountpoint = "legacy";
              options.recordsize = "1M";
            };
          };
        };

        "${poolName}-1" = {
          type = "zpool";
          options.ashift = "12";
          inherit rootFsOptions;

          datasets = {
            ${pseudoRoot}.type = "zfs_fs";

            "${pseudoRoot}/persist" = {
              type = "zfs_fs";
              mountpoint = "/persist";
              options = {
                mountpoint = "legacy";
              }
              // optionalAttrs (!vmInstall) {
                encryption = "aes-256-gcm";
                keyformat = "passphrase";
                keylocation = "prompt";
              };
            };

            "${pseudoRoot}/persist/videos" = {
              type = "zfs_fs";
              mountpoint = "/persist/home/${username}/videos";
              options.mountpoint = "legacy";
              options.recordsize = "1M";
            };

            "${pseudoRoot}/persist/pictures" = {
              type = "zfs_fs";
              mountpoint = "/persist/home/${username}/pictures";
              options.mountpoint = "legacy";
              options.recordsize = "1M";
            };

            "${pseudoRoot}/persist/music" = {
              type = "zfs_fs";
              mountpoint = "/persist/home/${username}/music";
              options.mountpoint = "legacy";
              options.recordsize = "1M";
            };

            "${pseudoRoot}/persist/downloads" = {
              type = "zfs_fs";
              mountpoint = "/persist/home/${username}/downloads";
              options.mountpoint = "legacy";
              options.recordsize = "1M";
            };

            "${pseudoRoot}/persist/vm-images" = {
              type = "zfs_fs";
              mountpoint = "/persist/images";
              options.mountpoint = "legacy";
              options.recordsize = "64K"; # optimised for qcow2 images
            };
          };
        };
      };
  };
}
