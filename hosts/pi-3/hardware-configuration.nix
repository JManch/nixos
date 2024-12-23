{ lib, pkgs, ... }:
{
  networking.hostId = "bc80a660";

  raspberry-pi-nix.board = "bcm2711";

  ${lib.ns}.hardware.raspberryPi.uboot = {
    enable = true;
    package = pkgs.ubootRaspberryPi3_64bit;
  };

  system.stateVersion = "24.05";
}
