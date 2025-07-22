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
          "/dev/disk/by-id/nvme-eui.000000000000000100a075254e014725";
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
              mountOptions = [ "umask=0077" ];
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
                crypttabExtraOpts = [
                  "tries=5"
                  # We don't need to measure the volume key in a PCR but this
                  # is needed to allow multiple tries of TPM pins
                  # https://github.com/systemd/systemd/issues/32041
                  "tpm2-measure-pcr=yes"
                  # I think the above disables the cryptsetup token plugin (the prompt that
                  # starts with "Please enter LUKS2 token PIN: ") so we've got to use native
                  # systemd TPM pin unlock
                  "tpm2-pin=yes"
                  "tpm2-device=auto"
                ];
              };

              # https://www.man7.org/linux/man-pages/man8/cryptsetup-luksFormat.8.html
              extraFormatArgs = [
                "--type=luks2"
                "--use-random" # true randomness at the cost of blocking if there isn't enough entropy
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
          size = if vmInstall then "4G" else "96G";
          content = {
            type = "swap";
            resumeDevice = true;
          };
        };

        nix = {
          size = if vmInstall then "20G" else "200G";
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
        "size=32g" # match ncase-m1
      ];
    };
  };

  # Initially enroll TPM key with: `systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7+12 --tpm2-with-pin=yes /dev/nvme0n1p2`
  # To re-enroll the key after the TPM has changed (e.g. after a firemware
  # update) additionally pass `--wipe-slot=tpm2` to replace the old key slot

  # Make hibernation images as small as possible
  systemd.tmpfiles.rules = [ "w /sys/power/image_size - - - - 0" ];
}
