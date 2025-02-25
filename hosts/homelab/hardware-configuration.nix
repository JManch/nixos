# Sometimes the GPU on this thing breaks causing frigate hwaccel to fail
# and monitor output to not work. CMOS reset does NOT fix it. I've fixed it
# before by removing the hard drive bay inside the case.

# The BCM 5762 network interface in this device has a problem where is will
# randomly crash under load and not reconnect until the device is reset:

# Relevant bug reports:
# https://bugzilla.kernel.org/show_bug.cgi?id=203607
# https://bugs.launchpad.net/ubuntu/+source/linux/+bug/1447664

# Crash kernel logs:
# homelab kernel: tg3 0000:01:00.0 enp1s0: NETDEV WATCHDOG: CPU: 3: transmit queue 0 timed out 6160 ms
# homelab kernel: tg3 0000:01:00.0 enp1s0: transmit timed out, resetting
# homelab kernel: tg3 0000:01:00.0: tg3_stop_block timed out, ofs=4c00 enable_bit=2

# I had it fixed for several months by setting adding the iommu=pt to the
# kernel params but after setting up secure boot on the device (probably
# unrelated), the problem re-appeared and I can't find a way to fix it. I'm
# just going to consider the ethernet port broken and just use a USB 3.0 to
# ethernet adapter.
{ modulesPath, ... }:
{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

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
  };

  system.stateVersion = "24.05";
}
