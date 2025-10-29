# WARN: Before performing bios updates disable the admin password. I think it
# can potentially cause issues after the bios reset.

# Bios options to change from default:

# Tweaker/
#   Precision Boost Overdrive: Disabled
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
  inputs,
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

    kernelPackages =
      assert lib.assertMsg (pkgs.zfs.version == "2.3.4") "zfs should support newer kernel now";
      lib.mkForce
        (import (fetchTree "github:NixOS/nixpkgs/544961dfcce86422ba200ed9a0b00dd4b1486ec5") {
          inherit (pkgs) system;
        }).linuxPackages_6_16;
    # kernelPackages = lib.mkForce pkgs.linuxPackages_6_16;
  };

  programs.ryzen-monitor-ng.enable = true;

  # Cause uni wifi sucks and slows down after a few hours unless we reassociate
  systemd.services."${inputs.nix-resources.secrets.ssids.uni}-reassociate" = {
    description = "Reassociate ${inputs.nix-resources.secrets.ssids.uni} connection";
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    script =
      let
        wpa_cli = lib.getExe' pkgs.wpa_supplicant "wpa_cli";
        interface = config.${lib.ns}.system.networking.wireless.interface;
      in
      # bash
      ''
        if [[ $(${wpa_cli} -i "${interface}" status | grep '^ssid=' | cut -d'=' -f2) == "${inputs.nix-resources.secrets.ssids.uni}" ]]; then
          echo "Reassociating with wireless network"
          ${wpa_cli} -i ${interface} reassociate
        else
          echo "Skipping reassociation"
        fi
      '';
  };

  systemd.timers."${inputs.nix-resources.secrets.ssids.uni}-reassociate" = {
    description = "Reassociate ${inputs.nix-resources.secrets.ssids.uni} connection timer";
    timerConfig = {
      OnBootSec = "2h";
      OnUnitActiveSec = "2h";
      RandomizedDelaySec = "30m";
    };
    wantedBy = [ "timers.target" ];
  };

  system.stateVersion = "24.05";
}
