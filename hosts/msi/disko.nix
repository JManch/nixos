{ inputs, ... }:
{
  imports = [ inputs.disko.nixosModules.default ];

  disko.devices.disk."1TB-SATA" = {
    type = "disk";
    device =
      if inputs.vmInstall.value then
        "/dev/disk/by-path/pci-0000:04:00.0"
      else
        "/dev/disk/by-id/ata-CT1000MX500SSD1_2114E59329CE";
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
}
