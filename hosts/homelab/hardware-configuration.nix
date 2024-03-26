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
    kernelParams = [ "pcie_aspm=off" ];
  };
}
