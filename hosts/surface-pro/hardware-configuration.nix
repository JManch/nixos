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

    # https://github.com/linux-surface/linux-surface/issues/1060
    blacklistedKernelModules = [ "surface_gpe" ];
  };

  # suspend-then-hibernate is broken. For some reason after HibernateDelaySec
  # have passed the system wakes up from suspend and, instead of hibernating,
  # stays awake.
  # systemd.sleep.extraConfig = ''
  #   HibernateDelaySec=30m
  # '';

  services.logind = {
    # Power button doesn't work so these are pointless
    # https://github.com/linux-surface/linux-surface/issues/1424
    powerKey = "hibernate";
    powerKeyLongPress = "poweroff";
    lidSwitch = "suspend";
  };

  services.tlp.enable = true;

  system.stateVersion = "24.11";
}
