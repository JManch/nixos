{
  imports = [
    ./hardware-configuration.nix
    ./impermenance-home.nix
    ./windows.nix
    ./fans.nix

    ../common/global

    ../common/optional/virtualisation.nix
    ../common/optional/pipewire.nix
    ../common/optional/desktop.nix
    ../common/optional/nvidia.nix
    ../common/optional/winbox.nix
  ];

  networking.hostId = "625ec505";

  system.stateVersion = "23.05";
}
