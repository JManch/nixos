{ lib, config }:
let
  inherit (lib) ns mkIf;
  inherit (config.${ns}.core.device) gpu;
  inherit (config.${ns}.system) desktop;
  inherit (config.${ns}.core) home-manager;
in
{
  enableOpt = false;
  conditions = [ (gpu.type == "nvidia") ];

  hardware.graphics.enable = true;

  services.xserver.videoDrivers = mkIf desktop.enable [ "nvidia" ];

  hardware.nvidia = {
    open = true;
    branch = "stable";
    nvidiaSettings = false; # does not work on wayland
    videoAcceleration = true; # this installs nvidia-vaapi-driver
    powerManagement.enable = desktop.suspend.enable;
  };

  # Increase Nvidia's shader cache size to 12GB
  # https://wiki.cachyos.org/configuration/gaming/#increase-maximum-shader-cache-size
  environment.sessionVariables = {
    DXVK_HUD = "compiler";
    __GL_SHADER_DISK_CACHE_SIZE = "12000000000";
  };

  ns.hm = mkIf (home-manager.enable && config.hardware.nvidia.videoAcceleration) {
    programs.firefox.profiles.default.settings = {
      "media.hardware-video-decoding-vulkan.enabled" = true;
    };
  };

  ns.persistenceHome.directories = [ ".cache/nvidia" ];
}
