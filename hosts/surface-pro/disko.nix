{ inputs, hostname, ... }:
let
  vmInstall = inputs.vmInstall.value;
in
{
  imports = [ inputs.disko.nixosModules.default ];

  disko.devices = {
    disk.nixos = {
      type = "disk";
      device =
        if vmInstall then
          "/dev/disk/by-path/pci-0000:04:00.0"
        else
          "/dev/disk/by-id/nvme-eui.5cd2e41381d0a8fd";
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

          luks = {
            size = "100%";
            content = {
              type = "luks";
              name = "${hostname}-crypted";

              askPassword = true;
              settings = {
                allowDiscards = true; # enables trimming support
                bypassWorkqueues = true; # improves performance
              };

              # https://www.man7.org/linux/man-pages/man8/cryptsetup-luksFormat.8.html
              extraFormatArgs = [
                "--type=luks2"
                "--use-random" # true randomness at the cost of blocking if there isn't enough entropy
                # WARN: gets auto-detected but device needs to report correct sector size
                # "--sector-size=4096"
              ];

              content = {
                type = "lvm_pv";
                vg = "${hostname}-nixos";
              };
            };
          };
        };
      };
    };

    lvm_vg."${hostname}-nixos" = {
      type = "lvm_vg";
      lvs = {
        swap = {
          size = if vmInstall then "4G" else "11G";
          content = {
            type = "swap";
            resumeDevice = true;
          };
        };

        nix = {
          size = if vmInstall then "20G" else "50G";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/nix";
            mountOptions = [ "noatime" ];
          };
        };

        persist = {
          size = "100%";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/persist";
            mountOptions = [ "noatime" ];
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
