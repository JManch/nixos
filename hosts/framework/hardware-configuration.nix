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

    kernelPackages = lib.mkForce pkgs.linuxPackages_latest;

    # Force TLP to use cros_charge-control module instead of the framework
    # module for battery charge limits
    # FIX: Doesn't work for some reason, seems like we don't even have the
    # cros_charge module?
    # extraModprobeConfig = ''
    #   options cros_charge-control probe_with_fwk_charge_control=1
    # '';
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

  services.fwupd.enable = true;
  services.power-profiles-daemon.enable = false;
  services.tlp = {
    enable = true;
    settings = {
      # Battery
      # `tlp fullcharge` to disable threshold until AC is unplugged
      RESTORE_THRESHOLDS_ON_BAT = 1;
      START_CHARGE_THRESH_BAT1 = 75;
      STOP_CHARGE_THRESH_BAT1 = 80;

      # Graphics
      RADEON_DPM_PERF_LEVEL_ON_AC = "auto";
      RADEON_DPM_PERF_LEVEL_ON_BAT = "auto";
      RADEON_DPM_STATE_ON_AC = "performance";
      RADEON_DPM_STATE_ON_BAT = "battery";
      AMDGPU_ABM_LEVEL_ON_AC = "0";
      AMDGPU_ABM_LEVEL_ON_BAT = "2";

      # Networking
      WIFI_PWR_ON_AC = "off";
      WIFI_PWR_ON_BAT = "off"; # attempt to improve poor wifi performance

      # Platform
      PLATFORM_PROFILE_ON_AC = "performance"; # sysbench cpu run --threads=24 (balanced is 50194 events/s)
      PLATFORM_PROFILE_ON_BAT = "low-power"; # consider balanced

      # Processor
      # Not sure these are worth messing with...
      # CPU_DRIVER_OPMODE_ON_AC = "active";
      # CPU_DRIVER_OPMODE_ON_BAT = "active";

      # CPU_SCALING_GOVERNOR_ON_AC = "powersave";
      # CPU_SCALING_GOVERNOR_ON_BAT = "powersave";

      CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "power"; # consider balanced_power

      CPU_BOOST_ON_AC = 1;
      CPU_BOOST_ON_BAT = 0; # default without tlp is to boost on bat

      # Runtime
      RUNTIME_PM_ON_AC = "auto";
      RUNTIME_PM_ON_BAT = "auto";
    };
  };

  system.stateVersion = "25.05";
}
