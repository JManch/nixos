{ inputs, pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./impermenance-home.nix
    ./fans.nix
    ../common/global
    ../common/users/joshua

    ../common/optional/nvidia.nix
    ../common/optional/desktop.nix
    ../common/optional/pipewire.nix
    ../common/optional/virtualisation.nix
  ];

  networking.hostName = "ncase-m1";
  networking.hostId = "625ec505";

  system.stateVersion = "23.05";
}
