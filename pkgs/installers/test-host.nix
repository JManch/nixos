{
  encryption ? false,
  secureBoot ? false,
  impermanence ? false,
  wireless ? false,
}:
{ lib, inputs, ... }:
{
  imports = [ inputs.disko.nixosModules.default ];

  ${lib.ns} = {
    core = {
      home-manager.enable = false;

      device = {
        type = "server";
        address = "192.168.88.254"; # FIX:
        memory = 1024 * 4; # FIX:

        cpu = {
          type = "amd";
          cores = 4;
        };
      };
    };

    # FIX: Can have this and impermanence enabled in seperate tests
    # hardware.secure-boot.enable = false;
    hardware.file-system.type = "ext4";
    hardware.file-system.ext4.trim = false;

    system = {
      networking = {
        wiredInterface = "eno1"; # FIX:
        defaultGateway = "192.168.88.1"; # FIX:

        # FIX: Separate test
        # wireless = {
        #   enable = true;
        #   interface = "wlp6s0";
        #   disableOnBoot = true;
        # };
      };
    };
  };

  disko.devices = {
    disk.nixos = {
      type = "disk";
      device = "/dev/vda";
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
          root = {
            size = "100%";
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/";
            };
          };
        };
      };
    };
  };
}
