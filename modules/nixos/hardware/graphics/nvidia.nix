{ lib
, pkgs
, config
, outputs
, username
, hostname
, ...
}:
let
  nvidia = config.device.gpu.type == "nvidia";
  desktop = config.usrEnv.desktop.enable;
  homeManagerConfig = outputs.nixosConfigurations.${hostname}.config.home-manager.users.${username};
in
lib.mkIf nvidia
{
  hardware.opengl = {
    enable = true;
    driSupport = true;
    driSupport32Bit = true;
    extraPackages = [
      pkgs.vaapiVdpau # hardware acceleration
      pkgs.nvidia-vaapi-driver
    ];
  };

  services.xserver.videoDrivers = lib.mkIf desktop [ "nvidia" ];

  hardware.nvidia = {
    # Major issues if this is disabled
    modesetting.enable = true;
    open = true;
    nvidiaSettings = !(lib.fetchers.isWayland homeManagerConfig);
  };

  environment.persistence."/persist".users.${username}.directories = [
    ".cache/nvidia"
  ];
}
