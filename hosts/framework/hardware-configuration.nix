# Issues:
# https://gitlab.freedesktop.org/mesa/mesa/-/issues/12528
# https://github.com/openwrt/mt76/issues/548
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

  ${lib.ns}.hardware.graphics.amd.kernelPatches = [
    # Fix for https://gitlab.freedesktop.org/mesa/mesa/-/issues/12528
    (pkgs.fetchpatch2 {
      url = "https://gitlab.freedesktop.org/-/project/176/uploads/d6a7812beec2760eccdd1f0439923277/vcn4_0_5-6.15-rc5.patch";
      hash = "sha256-y+Lvq5QefQ3kNNAuLEbfTedN6Pz9dtf1ma4jtpdslyI=";
    })
  ];

  boot = {
    kernelModules = [ "kvm-amd" ];

    initrd.availableKernelModules = [
      "nvme"
      "xhci_pci"
      "thunderbolt"
      "usb_storage"
      "sd_mod"
    ];

    kernelPackages =
      lib.mkForce
        (import (fetchTarball {
          url = "https://github.com/JManch/nixpkgs/archive/ef9fc863c9a6bf7d89c772116a9259c1284c6f25.tar.gz";
          sha256 = "sha256:073cc99n1819prv6f3d1p9mn7zfxc7yn1hw0i7rs1z3hizx8srbf";
        }) { inherit (pkgs) system; }).linuxPackages_testing;

    # Force TLP to use cros_charge-control module instead of the framework
    # module for battery charge limits
    # FIX: Doesn't work for some reason, seems like we don't even have the
    # cros_charge module?
    # extraModprobeConfig = ''
    #   options cros_charge-control probe_with_fwk_charge_control=1
    # '';
  };

  programs.zsh = {
    shellAliases."get-pps" = "cat /sys/class/drm/card1-eDP-1/amdgpu/panel_power_savings";
    interactiveShellInit = # bash
      ''
        toggle-pps() {
          sysfs_path="/sys/class/drm/card1-eDP-1/amdgpu/panel_power_savings"

          set_pps() {
            echo "$1" | sudo tee "$sysfs_path" > /dev/null
            if [[ $? -ne 0 ]]; then
                echo "Failed to write to '$sysfs_path'" >&2
                exit 1
            fi
          }

          if [[ "$(cat "$sysfs_path")" != "0" ]]; then
            set_pps 0
            echo "Panel power savings disabled"
          else
            set_pps 2
            echo "Panel power savings enabled"
          fi
        }
      '';
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

  services.fwupd.enable = false; # enable when necessary
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

      # Platform (affects TDP apparently)
      PLATFORM_PROFILE_ON_AC = "performance";
      PLATFORM_PROFILE_ON_BAT = "low-power"; # consider balanced

      # Processor
      # Not sure these are worth messing with...
      # CPU_DRIVER_OPMODE_ON_AC = "active";
      # CPU_DRIVER_OPMODE_ON_BAT = "active";

      # CPU_SCALING_GOVERNOR_ON_AC = "powersave";
      # CPU_SCALING_GOVERNOR_ON_BAT = "powersave";

      # https://community.frame.work/t/tracking-ppd-v-tlp-for-amd-ryzen-7040/39423/292
      CPU_ENERGY_PERF_POLICY_ON_AC = "balance_performance"; # consider performance
      CPU_ENERGY_PERF_POLICY_ON_BAT = "balance_power";

      CPU_BOOST_ON_AC = 1;
      CPU_BOOST_ON_BAT = 0; # default without tlp is to boost on bat

      # Runtime
      RUNTIME_PM_ON_AC = "auto";
      RUNTIME_PM_ON_BAT = "auto";
    };
  };

  # Disable the airplane mode key
  services.udev.extraHwdb = ''
    evdev:input:b0018v32ACp0006*
      KEYBOARD_KEY_100c6=reserved
  '';

  system.stateVersion = "25.05";
}
