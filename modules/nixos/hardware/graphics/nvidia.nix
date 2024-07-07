{ lib, pkgs, config, ... }:
let
  inherit (lib) mkIf;
  inherit (config.modules.system.desktop) isWayland;
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
    open = true;
    nvidiaSettings = !isWayland;
    # Enable this for suspend
    powerManagement.enable = false;
  };

  # Completely disable suspend and hibernate as it seems broken on nvidia and
  # accidentally pressing the button in gnome can put the system in a broken
  # state
  systemd = {
    targets = {
      sleep = {
        enable = false;
        unitConfig.DefaultDependencies = "no";
      };
      suspend = {
        enable = false;
        unitConfig.DefaultDependencies = "no";
      };
      hibernate = {
        enable = false;
        unitConfig.DefaultDependencies = "no";
      };
      hybrid-sleep = {
        enable = false;
        unitConfig.DefaultDependencies = "no";
      };
    };
  };

  # Fixes extra ghost display
  boot.kernelParams = [ "nvidia-drm.fbdev=1" ];

  persistenceHome.directories = [ ".cache/nvidia" ];
}
