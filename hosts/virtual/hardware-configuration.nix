{ config
, lib
, modulesPath
, ...
}: {
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];

  boot = {
    initrd.availableKernelModules = [ "ahci" "xhci_pci" "virtio_pci" "sr_mod" "virtio_blk" ];
    initrd.kernelModules = [ ];
    kernelModules = [ "kvm-amd" ];
    kernelPackages = config.boot.zfs.package.latestCompatibleLinuxPackages;
    zfs.devNodes = "/dev/disk/by-partuuid";
  };

  fileSystems."/".options = lib.mkForce [ "size=1G" "mode=755" ];

  networking.useDHCP = lib.mkDefault true;
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
