{ lib, pkgs, config, ... }:
let
  inherit (lib) mkIf;
  inherit (config.modules.system.desktop) isWayland suspend;
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
    package = config.boot.kernelPackages.nvidiaPackages.stable;
    # Major issues if this is disabled
    modesetting.enable = true;
    # Eventually enable this
    open = false;
    nvidiaSettings = !isWayland;
    powerManagement.enable = suspend.enable;
  };

  # Fixes extra ghost display
  boot.kernelParams = [ "nvidia-drm.fbdev=1" ];

  persistenceHome.directories = [ ".cache/nvidia" ];
}
