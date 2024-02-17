{ modulesPath, ... }:
{
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];

  networking.useDHCP = true;
  hardware.cpu.amd.updateMicrocode = true;
  nixpkgs.hostPlatform = "x86_64-linux";

  boot = {
    initrd.availableKernelModules = [ "ahci" "xhci_pci" "virtio_pci" "sr_mod" "virtio_blk" ];
    kernelModules = [ "kvm-amd" ];
    zfs.devNodes = "/dev/disk/by-partuuid";
  };
}
