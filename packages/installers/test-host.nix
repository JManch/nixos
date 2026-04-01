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
        address = "10.0.2.15";
        memory = 1024 * 4;
      };
    };

    # hardware.secure-boot.enable = false;
    hardware.file-system.type = "ext4";
    hardware.file-system.ext4.trim = false;

    system = {
      networking = {
        wiredInterface = "eth0";
        defaultGateway = "10.0.2.2";
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
