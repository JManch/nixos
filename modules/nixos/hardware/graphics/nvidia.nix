{
  lib,
  pkgs,
  config,
  ...
}:
let
  inherit (lib) ns mkIf;
  inherit (config.${ns}.system.desktop) suspend;
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
    nvidiaSettings = false; # does not work on wayland
    powerManagement.enable = suspend.enable;
  };

  persistenceHome.directories = [ ".cache/nvidia" ];
}
