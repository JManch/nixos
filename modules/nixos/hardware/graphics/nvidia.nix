{
  ns,
  lib,
  pkgs,
  config,
  ...
}:
let
  inherit (lib) mkIf;
  inherit (config.${ns}.system.desktop) isWayland suspend;
in
mkIf (config.${ns}.device.gpu.type == "nvidia") {
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      vaapiVdpau
      nvidia-vaapi-driver
    ];
  };

  services.xserver.videoDrivers = mkIf config.${ns}.system.desktop.enable [ "nvidia" ];

  hardware.nvidia = {
    package = config.boot.kernelPackages.nvidiaPackages.stable;
    open = true;
    nvidiaSettings = !isWayland;
    powerManagement.enable = suspend.enable;
  };

  persistenceHome.directories = [ ".cache/nvidia" ];
}
