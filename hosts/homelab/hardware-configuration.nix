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

    # Fixes intermittent ethernet failure
    # https://bugzilla.kernel.org/show_bug.cgi?id=203607
    # https://bugs.launchpad.net/ubuntu/+source/linux/+bug/1447664
    kernelParams = [ "iommu=pt" ];
  };
}
