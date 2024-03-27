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
    # Attempt to fix intermittent ethernet failure
    # (issue still occured with pcie_asmp=off, testing now with extra 3)
    # Disabling acpi prevents "software" shutdowns of the system so I will have
    # to physically press the power button
    # Using acpi=off breaks cpu detection so only 1 core shows
    kernelParams = [ "pcie_aspm=off" "noapic" "pci=noacpi" ];
  };
}
