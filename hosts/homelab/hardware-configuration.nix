{ modulesPath, ... }:
{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  hardware.cpu.amd.updateMicrocode = true;
  nixpkgs.hostPlatform = "x86_64-linux";

  boot = {
    initrd.availableKernelModules = [ "xhci_pci" "ahci" "ehci_pci" "nvme" ];
    kernelModules = [ "kvm-amd" ];
    # TODO: This is needed to mount in VM, check if it's needed for bare metal
    zfs.devNodes = "/dev/disk/by-partuuid";
  };
}
