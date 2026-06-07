{
  lib,
  pkgs,
  config,
}:
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

  # https://github.com/elFarto/nvidia-vaapi-driver#configuration
  environment =
    assert lib.assertMsg (
      !lib.hasPrefix "153" pkgs.firefox.version
    ) "Firefox should support vulkan hardware decode";
    {
      systemPackages = [ pkgs.libva-utils ];
      variables = {
        MOZ_DISABLE_RDD_SANDBOX = 1;
        NVD_BACKEND = "direct";
        LIBVA_DRIVER_NAME = "nvidia";
      };
    };

  ns.hm = mkIf (home-manager.enable && config.hardware.nvidia.videoAcceleration) {
    programs.firefox.profiles.default.settings = {
      "media.hardware-video-decoding.force-enabled" = true;
      "media.av1.enabled" = true; # override to false on a per-host basis
      "gfx.x11-egl.force-enabled" = true;
      "widget.dmabuf.force-enabled" = true;
    };
  };

  ns.persistenceHome.directories = [ ".cache/nvidia" ];
}
