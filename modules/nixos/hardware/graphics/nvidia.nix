{ lib
, pkgs
, config
, ...
} @ args:
let
  inherit (lib) utils mkIf fetchers;
  homeConfig = utils.homeConfig args;
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

  services.xserver.videoDrivers = mkIf config.usrEnv.desktop.enable [ "nvidia" ];

  hardware.nvidia = {
    # Major issues if this is disabled
    modesetting.enable = true;
    open = true;
    nvidiaSettings = !(fetchers.isWayland homeConfig);
  };

  persistenceHome.directories = [
    ".cache/nvidia"
  ];
}
