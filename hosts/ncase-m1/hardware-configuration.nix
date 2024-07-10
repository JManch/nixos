{
  networking.hostId = "625ec505";
  hardware.cpu.amd.updateMicrocode = true;

  boot = {
    initrd.availableKernelModules = [ "nvme" "xhci_pci" "ahci" "usbhid" "usb_storage" "sd_mod" ];
    kernelModules = [ "kvm-amd" ];
  };

  system.stateVersion = "23.05";
}
