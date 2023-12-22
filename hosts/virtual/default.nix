{
  inputs,
  pkgs,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    ./impermenance-home.nix
    ../common/global
    ../common/users/joshua
  ];

  networking.hostName = "virtual";
  networking.hostId = "8d4ed64c";

  services.xserver = {
    enable = true;
    desktopManager.xfce.enable = true;
    displayManager.defaultSession = "xfce";
  };

  system.stateVersion = "23.05";
}
