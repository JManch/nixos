{ inputs, ... }:
{
  imports = [ inputs.nixos-hardware.nixosModules.microsoft-surface-pro-intel ];

  networking.hostId = "06e74829";
  hardware.cpu.intel.updateMicrocode = true;

  boot = {
    kernelModules = [ "kvm-intel" ];

    initrd.availableKernelModules = [
      "xhci_pci"
      "nvme"
      "usb_storage"
      "sd_mod"
    ];
  };

  system.stateVersion = "24.11";
}
