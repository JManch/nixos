{ lib, pkgs, config, ... }:
let
  inherit (lib) mkIf fetchers;
in
mkIf (config.device.gpu.type == "nvidia")
{
  hardware.opengl = {
    enable = true;
    driSupport = true;
    driSupport32Bit = true;
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
    nvidiaSettings = !(fetchers.isWayland config);
  };

  persistenceHome.directories = [
    ".cache/nvidia"
  ];
}
