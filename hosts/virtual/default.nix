{ inputs, pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./impermenance-home.nix
    ../common/global
    ../common/users/joshua
    inputs.home-manager.nixosModules.home-manager
  ];

  home-manager = {
    extraSpecialArgs = { inherit inputs; };
    users = {
      joshua = import ../../home/virtual.nix;
    };
  };

  networking.hostName = "virtual";
  networking.hostId = "8d4ed64c";

  services.xserver = {
    enable = true;
    desktopManager.xfce.enable = true;
    displayManager.defaultSession = "xfce";
  };

  system.stateVersion = "23.05";
}
