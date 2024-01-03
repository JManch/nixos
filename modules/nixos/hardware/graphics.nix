{ config
, pkgs
, lib
, username
, ...
}:
let
  inherit (lib) mkIf;
  nvidia = config.device.gpu == "nvidia";
  amd = config.device.gpu == "amd";
  optional = lib.lists.optional;
in
lib.mkIf (config.device.gpu != null) {
  # AMD Driver Explanation
  # There are two main AMD drivers: AMDVLK and RADV. AMDVLK is the offical open
  # source driver provided by AMD whilst RADV is made by Valve. Depending on
  # the application, one may perform better than the other so it's useful to
  # have both installed and toggle between them. RADV is installed as part of
  # the Mesa driver package which is installed when hardware.opengl.enable is
  # set. AMDVLK is installed through the extraPackages option.

  hardware.opengl = {
    enable = true;
    driSupport = true;
    driSupport32Bit = true;
    extraPackages = with pkgs;
      optional nvidia vaapiVdpau # nvidia hardware acceleration
      ++ optional amd amdvlk;
  };

  # Leave this as default setting for AMD
  services.xserver.videoDrivers = mkIf nvidia [ "nvidia" ];

  hardware.nvidia = mkIf nvidia {
    # Major issues if this is disabled
    modesetting.enable = true;
    open = true;
    nvidiaSettings = !(lib.validators.isWayland config);
  };

  environment.persistence."/persist".users.${username}.directories =
    mkIf (config.device.gpu == "nvidia") [
      ".cache/nvidia"
    ];
}
