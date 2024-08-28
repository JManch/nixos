{ lib, ... }:
{
  networking.hostId = "bc80a660";

  # nixpkgs.overlays = [
  #   (_final: super: {
  #     makeModulesClosure = x: super.makeModulesClosure (x // { allowMissing = true; });
  #   })
  # ];

  # The last console argument in the list that linux can find at boot will receive kernel logs.
  # The serial ports listed here are:
  # - ttyS0: serial
  # - tty0: hdmi
  boot.kernelParams = [
    "console=ttyS0,115200n8"
    "console=tty0"
  ];

  # zfs has a dependency on samba which is broken under cross compilation
  boot.supportedFilesystems.zfs = lib.mkForce false;

  system.stateVersion = "24.05";
}
