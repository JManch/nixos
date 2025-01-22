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

  systemd.sleep.extraConfig = ''
    HibernateDelaySec=30m
    SuspendState=mem
  '';

  services.logind = {
    powerKey = "suspend-then-hibernate";
    powerKeyLongPress = "poweroff";
    lidSwitch = "suspend-then-hibernate";
  };

  services.tlp.enable = true;

  system.stateVersion = "24.11";
}
