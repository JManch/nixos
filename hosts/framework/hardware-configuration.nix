{
  lib,
  pkgs,
  inputs,
  modulesPath,
  ...
}:
{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    # nixos-hardware does not have a framework ai 300 module yet
    (inputs.nixos-hardware + "/framework/13-inch/common")
    (inputs.nixos-hardware + "/framework/13-inch/common/amd.nix")
  ];

  networking.hostId = "549d3e08";
  hardware.cpu.amd.updateMicrocode = true;

  boot = {
    kernelModules = [ "kvm-amd" ];

    initrd.availableKernelModules = [
      "nvme"
      "xhci_pci"
      "thunderbolt"
      "usb_storage"
      "sd_mod"
    ];

    # HACK: Temporarily using testing for kernel >=6.15 to fix MT7925 wifi drop outs
    kernelPackages = lib.mkForce pkgs.linuxPackages_testing;
  };

  # https://www.freedesktop.org/software/systemd/man/latest/sleep.conf.d.html
  systemd.sleep.extraConfig = ''
    HibernateDelaySec=30m
    HibernateOnACPower=no
    SuspendState=mem
    # deep sleep is not supported sadly
    MemorySleepMode=s2idle
  '';

  services.logind = {
    powerKey = "poweroff";
    lidSwitch = "suspend-then-hibernate";
  };

  services.tlp.enable = true;
  services.power-profiles-daemon.enable = false;

  system.stateVersion = "25.05";
}
