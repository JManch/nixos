# Issues:
# - https://github.com/openwrt/mt76/issues/548
# - Userspace charge limiter has been broken since the 3.04 bios update https://github.com/tlvince/nixos-config/issues/309
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
    (inputs.nixos-hardware + "/framework/13-inch/amd-ai-300-series")
  ];

  networking.hostId = "549d3e08";
  hardware.cpu.amd.updateMicrocode = true;

  # As of kernel 6.13 the framework kmod isn't necessary
  hardware.framework.enableKmod = false;

  nixpkgs.overlays =
    # Supposedly 6.18rc5+ and latest microcode offer improved battery life
    assert lib.assertMsg (
      inputs.nixpkgs.rev == "c5ae371f1a6a7fd27823bc500d9390b38c05fa55"
    ) "remove or update framework kernel fast-forward";
    [
      (_: _: {
        inherit
          (import (fetchTree "github:JManch/nixpkgs/af98bc070c697dc92f160f0242ab961f773ddc6c") {
            inherit (pkgs.stdenv.hostPlatform) system;
          })
          linux-firmware
          linuxPackages_testing
          ;
      })
    ];

  boot = {
    # Using testing in an attempt to fix suspend-then-hibernate issues.
    kernelPackages = pkgs.linuxPackages_testing;
    # kernelPackages = pkgs.linuxPackages_latest;

    kernelModules = [ "kvm-amd" ];

    initrd.availableKernelModules = [
      "nvme"
      "xhci_pci"
      "thunderbolt"
      "usb_storage"
      "sd_mod"
    ];

    # Contrary to what the tlp docs say, we need probe_with_fwk_charge_control=1
    # even though we do not use the custom framework kmod
    # extraModprobeConfig = ''
    #   options cros_charge_control probe_with_fwk_charge_control=1
    # '';

    # https://github.com/FrameworkComputer/SoftwareFirmwareIssueTracker/issues/70
    # kernelPatches = lib.singleton {
    #   name = "cros-charge-fix";
    #   patch = pkgs.fetchpatch2 {
    #     url = "https://lore.kernel.org/lkml/20250521-cros-ec-mfd-chctl-probe-v1-1-6ebfe3a6efa7@weissschuh.net/raw";
    #     hash = "sha256-Lt12B/JgEbmOOdRX28hs1t/khySxbB2FG3W1y8nj1us=";
    #   };
    # };
  };

  services.upower = {
    enable = true;
    criticalPowerAction = "Hibernate";
    # Framework hardware supports battery events
    noPollBatteries = true;
  };

  systemd.services.disable-power-led = {
    description = "Disable power LED";
    serviceConfig.Type = "oneshot";
    script = "echo 0 > /sys/class/leds/chromeos:white:power/brightness";
    wantedBy = [ "multi-user.target" ];
  };

  # Also disable LED when resuming from hibernation
  environment.etc."systemd/system-sleep/post-hibernate-disable-power-led".source =
    pkgs.writeShellScript "post-hibernate-disable-power-led" ''
      if [ "$1-$SYSTEMD_SLEEP_ACTION" = "post-hibernate" ]; then
        echo 0 > /sys/class/leds/chromeos:white:power/brightness
      fi
    '';

  programs.zsh = {
    shellAliases = {
      "get-pps" = "cat /sys/class/drm/card1-eDP-1/amdgpu/panel_power_savings";
      "led-off" = "echo 0 | sudo tee /sys/class/leds/chromeos:white:power/brightness >/dev/null";
      "led-on" = "echo 1 | sudo tee /sys/class/leds/chromeos:white:power/brightness >/dev/null";
    };

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
    HibernateDelaySec=2h
    HibernateOnACPower=no
    SuspendState=mem
    # deep sleep is not supported sadly
    MemorySleepMode=s2idle
  '';

  services.logind.settings.Login = {
    HandlePowerKey = "poweroff";
    HandleLidSwitch = "suspend-then-hibernate";
  };

  services.fwupd.enable = lib.mkForce false; # enable when necessary
  services.power-profiles-daemon.enable = false;
  services.tlp = {
    enable = true;
    settings = {
      # Battery
      # `tlp fullcharge` to disable threshold until AC is unplugged
      # RESTORE_THRESHOLDS_ON_BAT = 1;
      # START_CHARGE_THRESH_BAT1 = 75;
      # STOP_CHARGE_THRESH_BAT1 = 80;

      # Graphics
      RADEON_DPM_PERF_LEVEL_ON_AC = "auto";
      RADEON_DPM_PERF_LEVEL_ON_BAT = "auto";
      RADEON_DPM_STATE_ON_AC = "performance";
      RADEON_DPM_STATE_ON_BAT = "battery";
      AMDGPU_ABM_LEVEL_ON_AC = "0";
      AMDGPU_ABM_LEVEL_ON_BAT = "0";

      # Networking
      WIFI_PWR_ON_AC = "off";
      WIFI_PWR_ON_BAT = "off"; # attempt to improve poor wifi performance

      # Platform (affects TDP apparently)
      # https://www.phoronix.com/review/framework-13-ryzen-ai-power
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

  # Set minimum initial brightness to 50% so we can see TTY outdoors
  # https://www.man7.org/linux/man-pages/man8/systemd-backlight.8.html
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="backlight", KERNEL=="amdgpu_bl1", ENV{ID_BACKLIGHT_CLAMP}="50%%"
  '';

  # Disable the airplane mode key
  services.udev.extraHwdb = ''
    evdev:input:b0018v32ACp0006*
      KEYBOARD_KEY_100c6=reserved
  '';

  system.stateVersion = "25.05";
}
