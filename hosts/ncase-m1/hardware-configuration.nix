# WARN: Before performing bios updates disable the admin password. I think it
# can potentially cause issues after the bios reset.

# Bios options to change from default:

# Tweaker/
#   Precision Boost Overdrive: Disable
#   Advanced CPU Settings/
#     SVM Mode: Enabled
#     Global C-state Control: Enabled
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
{ lib, pkgs, ... }:
{
  networking.hostId = "625ec505";
  hardware.cpu.amd.updateMicrocode = true;

  # Fix for motherboard-specific suspend issue
  # https://wiki.archlinux.org/title/Power_management/Wakeup_triggers#Gigabyte_motherboards
  # https://wiki.archlinux.org/title/Power_management/Suspend_and_hibernate#PC_will_not_wake_from_sleep_on_A520I_and_B550I_motherboards
  services.udev.extraRules = ''
    KERNEL=="0000:00:01.1", SUBSYSTEM=="pci", DRIVER=="pcieport", ATTR{vendor}=="0x1022", ATTR{device}=="0x1483", ATTR{power/wakeup}="disabled"
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

    # kernelPackages =
    #   lib.mkForce
    #     (import (fetchTarball {
    #       url = "https://github.com/NixOS/nixpkgs/archive/2768c7d042a37de65bb1b5b3268fc987e534c49d.tar.gz";
    #       sha256 = "sha256:17pikpqk1icgy4anadd9yg3plwfrsmfwv1frwm78jg2rf84jcmq2";
    #     }) { inherit (pkgs) system; }).linuxPackages_6_10;
    kernelPackages = lib.mkForce pkgs.linuxPackages_6_12;
  };

  system.stateVersion = "24.05";
}
