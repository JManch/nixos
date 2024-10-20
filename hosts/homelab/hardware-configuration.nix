# WARN: Sometimes the GPU on this thing breaks causing frigate hwaccel to fail
# and monitor output to not work. CMOS reset does NOT fix it. I've fixed it
# before by removing the hard drive bay inside the case.
{
  networking.hostId = "8d4ed64c";
  hardware.cpu.amd.updateMicrocode = true;

  boot = {
    initrd.availableKernelModules = [
      "xhci_pci"
      "ahci"
      "ehci_pci"
      "nvme"
    ];
    kernelModules = [ "kvm-amd" ];

    # Fixes intermittent ethernet failure
    # https://bugzilla.kernel.org/show_bug.cgi?id=203607
    # https://bugs.launchpad.net/ubuntu/+source/linux/+bug/1447664
    kernelParams = [ "iommu=pt" ];
  };

  system.stateVersion = "24.05";
}
