{ lib, pkgs, ... }:
{
  networking.hostId = "bc80a660";

  raspberry-pi-nix.board = "bcm2711";

  ${lib.ns}.hardware.raspberry-pi.uboot = {
    enable = true;
    package = pkgs.ubootRaspberryPi3_64bit;
  };

  # Enable audio support
  hardware.raspberry-pi.config.all = {
    base-dt-params.audio = {
      enable = true;
      value = "on";
    };
  };

  system.stateVersion = "24.05";
}
