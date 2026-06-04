# Bios options to change from default:

# System Status
#   Date and time might be wrong
# Advanced/Windows OS Configuration
#   Windows 8.1/10 WHQL Support: Enabled (needed to enable secure option below)
#   Secure Boot/
#     Secure Boot Support: Enabled
# Boot/You can now reboot your system. After you've booted, Secure Boot is activated and in user mode:
#   Full Screen Logo Display: Disabled
# Security/
#   Administrator Password: set
#   Trusted Computing/
#     Security Device Support: Enabled
#     Hash policy: SHA-2
{
  lib,
  config,
  modulesPath,
  ...
}:
{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  networking.hostId = "de08204b";

  boot = {
    initrd.availableKernelModules = [
      "xhci_pci"
      "ahci"
      "usbhid"
      "usb_storage"
      "sd_mod"
    ];
    kernelModules = [ "kvm-intel" ];
  };

  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  system.stateVersion = "26.05";
}
