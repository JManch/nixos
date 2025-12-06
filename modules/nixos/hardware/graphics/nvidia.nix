{
  lib,
  pkgs,
  config,
}:
let
  inherit (lib) ns mkIf;
  inherit (config.${ns}.core.device) gpu;
  inherit (config.${ns}.system) desktop;
in
{
  enableOpt = false;
  conditions = [ (gpu.type == "nvidia") ];

  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      libva-vdpau-driver
      nvidia-vaapi-driver
    ];
  };

  services.xserver.videoDrivers = mkIf desktop.enable [ "nvidia" ];

  hardware.nvidia = {
    package = config.boot.kernelPackages.nvidiaPackages.stable;
    open = true;
    nvidiaSettings = false; # does not work on wayland
    powerManagement.enable = desktop.suspend.enable;
  };

  ns.persistenceHome.directories = [ ".cache/nvidia" ];
}
