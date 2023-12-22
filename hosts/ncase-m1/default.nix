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

    inputs.home-manager.nixosModules.home-manager
  ];

  home-manager = {
    extraSpecialArgs = { inherit inputs; };
    users = {
      joshua = import ../../home/ncase-m1.nix;
    };
  };

  networking.hostName = "ncase-m1";
  networking.hostId = "625ec505";

  system.stateVersion = "23.05";
}
