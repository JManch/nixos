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
  };

  persistenceHome.directories = [
    ".cache/nvidia"
  ];
}
