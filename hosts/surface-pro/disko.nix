{ inputs, ... }:
{
  imports = [ inputs.disko.nixosModules.default ];

  disko.devices = {
    disk.nixos = {
      type = "disk";
      device = "/dev/disk/by-id/nvme-eui.5cd2e41381d0a8fd";
      content = {
        type = "gpt";
        partitions = {
          esp = {
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
          nix = {
            end = "+50G";
            priority = 500;
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/nix";
            };
          };
          root = {
            end = "-11G";
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/persist";
            };
          };
          swap = {
            size = "100%";
            content = {
              type = "swap";
              resumeDevice = true;
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
  };
}
