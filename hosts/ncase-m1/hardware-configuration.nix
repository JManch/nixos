# WARN: Before performing bios updates disable the admin password. I think it
# can potentially cause issues after the bios reset.

# Bios options to change from default:

# Tweaker/
#   Precision Boost Overdrive: Enabled (enabling this was supposed to give +100mhz clock speed on all cores but I've seen no change)
#   Advanced CPU Settings/
#     SVM Mode: Enabled
#     Global C-state Control: Disabled (fixes USB issues)
#   Extreme Memory Profile(X.M.P.): Profile1 DDR4-3600
# Settings/
#   Platform Power/
#     ErP: Enabled
#     Wake on LAN: Disabled
#   IO Ports/
#     Above 4G Decoding: Enabled
#     Re-Size BAR Support: Auto
#     APP Center Download & Install Configuration/
#       APP Center Download & Install: Disabled
#   Miscellaneous/
#     LEDs in System Power On State: Off
#   Smart Fan 5/
#     CPU_FAN (AIO pump. Only provides a reading, cannot control): Default
#     SYS_FAN1 (Intake CPU radiator fans)/
#       Speed Control: Manual
#       Temperature Input: CPU
#       Curve:
#         1: 50*C, 30%
#         2: 60*C, 33%
#         3: 70*C, 40%
#         4: 74*C, 60%
#         5: 80*C, 100%

# WARN: After changing the settings above save and reboot before proceeding.
# This is to prevent the bios going into a broken state from changing too
# many settings as I have painfully experienced before.

# Boot/
#   Security Option: Setup
#   Fast Boot: Enabled
#   Preferred Operation Mode: Advanced

# WARN: Save and reboot again at this stage before setting admin password

#   Administrator Password: **********************
{
  lib,
  pkgs,
  config,
  modulesPath,
  ...
}:
{
  # Tracker for second monitor flickering issue: https://gitlab.freedesktop.org/drm/amd/-/issues/2904

  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  networking.hostId = "625ec505";
  hardware.cpu.amd.updateMicrocode = true;

  # Fix for motherboard-specific suspend issue
  # https://wiki.archlinux.org/title/Power_management/Wakeup_triggers#Gigabyte_motherboards
  # https://wiki.archlinux.org/title/Power_management/Suspend_and_hibernate#PC_will_not_wake_from_sleep_on_A520I_and_B550I_motherboards
  services.udev.extraRules = ''
    KERNEL=="0000:00:01.1", SUBSYSTEM=="pci", DRIVER=="pcieport", ATTR{vendor}=="0x1022", ATTR{device}=="0x1483", ATTR{power/wakeup}="disabled"
    # Disable wakeup from keyboard press and mouse movement
    KERNEL=="0000:02:00.0", SUBSYSTEM=="pci", DRIVER=="xhci_hcd", ATTR{vendor}=="0x1022", ATTR{device}=="0x43ee", ATTR{power/wakeup}="disabled"
  '';

  boot = {
    initrd.availableKernelModules = [
      "nvme"
      "xhci_pci"
      "ahci"
      "usbhid"
      "usb_storage"
      "sd_mod"
    ];

    kernelModules = [ "kvm-amd" ];

    kernelParams = [
      # WARN: Disable this if you experience flickering or general instability
      # https://wiki.archlinux.org/title/AMDGPU#Boot_parameter
      "amdgpu.ppfeaturemask=0xffffffff"
    ];

    # kernelPackages =
    # assert lib.assertMsg (pkgs.zfs.version == "2.3.4") "zfs should support newer kernel now";
    # lib.mkForce
    #   (import (fetchTree "github:NixOS/nixpkgs/2fad6eac6077f03fe109c4d4eb171cf96791faa4") {
    #     inherit (pkgs.stdenv.hostPlatform) system;
    #   }).linuxPackages_6_17;

    kernelPackages = lib.mkForce (config.${lib.ns}.hardware.cachy-kernel.package "x86_64-v3");

    zfs.package = lib.mkForce pkgs.zfs;
  };

  ${lib.ns} = {
    services.lact = {
      enable = true;
      config = # yaml
        ''
          version: 5
          daemon:
            log_level: info
            admin_group: wheel
            disable_clocks_cleanup: false
          apply_settings_timer: 5
          current_profile: null
          auto_switch_profiles: false
          gpus:
            1002:744C-1EAE:7905-0000:09:00.0:
              fan_control_enabled: true
              fan_control_settings:
                mode: curve
                static_speed: 0.5
                temperature_key: edge
                interval_ms: 500
                curve:
                  65: 0.25
                  70: 0.5
                  75: 0.6
                  80: 0.65
                  90: 0.75
                spindown_delay_ms: 5000
                change_threshold: 2
              pmfw_options:
                acoustic_limit: 3300
                acoustic_target: 2000
                minimum_pwm: 15
                target_temperature: 80
                zero_rpm: true
                zero_rpm_threshold: 60
              # Run at 257 for slightly better performance but louder fans
              power_cap: 231.0
              performance_level: manual
              max_core_clock: 2394
              voltage_offset: -30
              power_profile_mode_index: 0
        '';
    };

    programs.gaming.gamemode.profiles =
      let
        ncat = lib.getExe' pkgs.nmap "ncat";
        jaq = lib.getExe pkgs.jaq;
        confirm = ''echo '{"command": "confirm_pending_config", "args": {"command": "confirm"}}' | ${ncat} -U /run/lactd.sock'';
        getId = ''echo '{"command": "list_devices"}' | ${ncat} -U /run/lactd.sock | ${jaq} -r ".data[0].id"'';

        setPowerCap =
          powerCap: # bash
          ''
            echo "{\"command\": \"set_power_cap\", \"args\": {\"id\": \"$id\", \"cap\": ${toString powerCap}}}" | ${ncat} -U /run/lactd.sock
            ${confirm}
          '';

        setPowerProfile =
          profileIndex: # bash
          ''
            echo "{\"command\": \"set_power_profile_mode\", \"args\": {\"id\": \"$id\", \"index\": ${toString profileIndex}}}" | ${ncat} -U /run/lactd.sock
            ${confirm}
          '';
      in
      {
        # Default gamemode behaviour is to just change the power profile to
        # 3D_FULL_SCREEN
        "default" = {
          start."lact" = ''
            id=$(${getId})
            ${setPowerProfile 1}
          '';

          stop."lact" = ''
            id=$(${getId})
            ${setPowerProfile 0}
          '';
        };

        "vr" = {
          start."lact" = ''
            id=$(${getId})
            ${setPowerProfile 4}
            ${setPowerCap 257}
          '';

          stop."lact" = ''
            id=$(${getId})
            ${setPowerProfile 0}
            ${setPowerCap 231}
          '';
        };

        # Use the high_perf profile for higher power cap of 257. In unigine
        # superposition 4k optimised gives an 8% FPS increase (122fps -> 132fps).
        # Max core clock speeds go 2000MHz -> 2200Mhz. Thermals are a fair bit
        # worse though, with a ~200rpm fan increase.
        "high_perf" = {
          includeDefaultProfile = true;

          start."lact" = ''
            id=$(${getId})
            ${setPowerCap 257}
          '';

          stop."lact" = ''
            id=$(${getId})
            ${setPowerCap 231}
          '';
        };
      };
  };

  # Does not build with lto kernel
  # programs.ryzen-monitor-ng.enable = true;

  system.stateVersion = "24.05";
}
