{ modulesPath, ... }:
{
  # TODO: Replace this with actual hardware config on deployment
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];

  hardware.cpu.amd.updateMicrocode = true;
  nixpkgs.hostPlatform = "x86_64-linux";

  boot = {
    initrd.availableKernelModules = [ "ahci" "xhci_pci" "virtio_pci" "sr_mod" "virtio_blk" ];
    kernelModules = [ "kvm-amd" ];
    # TODO: This is needed to mount in VM, check if it's needed for bare metal
    zfs.devNodes = "/dev/disk/by-partuuid";
  };
}
