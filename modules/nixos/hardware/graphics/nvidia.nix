{ lib, pkgs, config, ... }:
let
  inherit (lib) mkIf fetchers;
  inherit (config.modules.core) homeManager;
in
mkIf (config.device.gpu.type == "nvidia")
{
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      vaapiVdpau
      nvidia-vaapi-driver
    ];
  };

  services.xserver.videoDrivers = mkIf config.modules.system.desktop.enable [ "nvidia" ];

  hardware.nvidia = {
    package = config.boot.kernelPackages.nvidiaPackages.beta;
    # Major issues if this is disabled
    modesetting.enable = true;
    open = true;
    nvidiaSettings = !(fetchers.isWayland config homeManager.enable);
    # In an attempt to make suspend-to-ram work
    powerManagement.enable = true;
  };

  # Fixes extra ghost display
  boot.kernelParams = [ "nvidia-drm.fbdev=1" ];

  persistenceHome.directories = [ ".cache/nvidia" ];
}
