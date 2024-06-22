{ modulesPath, ... }:
{
  # TODO: Generate this
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  networking.hostId = "13bd7dcf";

  boot = {
    initrd.availableKernelModules = [ "nvme" "xhci_pci" "ahci" "usbhid" "usb_storage" "sd_mod" ];
    kernelModules = [ "kvm-amd" ];
  };
}
