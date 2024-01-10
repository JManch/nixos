{ lib
, pkgs
, config
, username
, ...
}:
let
  amd = config.device.gpu.type == "amd";
  desktop = config.usrEnv.desktop.enable;
in
lib.mkIf amd
{
  environment.systemPackages = [
    pkgs.amdgpu_top
  ];

  boot.initrd.kernelModules = lib.mkBefore [ "amdgpu" ];

  # AMD Driver Explanation
  # There are two main AMD user drivers: AMDVLK and RADV. AMDVLK is the offical
  # open source driver provided by AMD whilst RADV is made by Valve. Depending
  # on the application, one may perform better than the other so it's useful to
  # have both installed and toggle between them. RADV is installed as part of
  # the Mesa driver package which is installed when hardware.opengl.driSupport is
  # enabled. AMDVLK is installed through the extraPackages option. There is also
  # the kernel module driver component which is amdgpu.

  hardware.opengl = {
    enable = true;
    driSupport = true;
    driSupport32Bit = true;
    extraPackages = [
      # Might need to add extra hardware acceleration packages here
      pkgs.amdvlk
    ];
    extraPackages32 = with pkgs; [
      pkgs.driversi686Linux.amdvlk
    ];
  };

  environment.sessionVariables = {
    # Make radv the default driver as just installed amdvlk makes it default
    AMD_VULKAN_ICD = "RADV";
  };

  services.xserver.videoDrivers = lib.mkIf desktop [ "modesetting" ];

  environment.persistence."/persist".users.${username} = {
    directories = [
      ".cache/AMD"
      ".cache/mesa_shader_cache"
    ];
  };
}
