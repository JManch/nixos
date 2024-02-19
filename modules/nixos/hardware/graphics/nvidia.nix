{ lib
, pkgs
, config
, ...
} @ args:
let
  inherit (lib) utils mkIf fetchers;
  nvidia = config.device.gpu.type == "nvidia";
  desktop = config.usrEnv.desktop.enable;
  homeConfig = utils.homeConfig args;
in
mkIf nvidia
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

  services.xserver.videoDrivers = mkIf desktop [ "nvidia" ];

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
