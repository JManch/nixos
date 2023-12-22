{ pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./impermenance-home.nix
    ../common/global
    ../common/users/joshua
  ];

  networking.hostName = "virtual";
  networking.hostId = "8d4ed64c";

  system.stateVersion = "23.05";
}
