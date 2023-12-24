{
  imports = [
    ./hardware-configuration.nix
    ./impermenance-home.nix

    ../common/global
  ];

  networking.hostId = "8d4ed64c";

  services.xserver = {
    enable = true;
    desktopManager.xfce.enable = true;
    displayManager.defaultSession = "xfce";
  };

  system.stateVersion = "23.05";
}
