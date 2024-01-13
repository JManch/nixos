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

    # NOTE: Completely removing amdvlk for now because it seems that gamescope
    # does not adhere to AMD_VULKAN_ICD and uses amdvlk regardless, causing it
    # to not launch

    # extraPackages = [
    #   pkgs.amdvlk
    # ];
    # extraPackages32 = with pkgs; [
    #   pkgs.driversi686Linux.amdvlk
    # ];
  };

  environment.sessionVariables = {
    # Make radv the default driver
    AMD_VULKAN_ICD = "RADV";
  };

  services.xserver.videoDrivers = lib.mkIf desktop [ "modesetting" ];

  environment.persistence."/persist".users.${username} = {
    directories = [
      ".cache/AMD"
      ".cache/mesa_shader_cache"
    ];
    files = [
      # NOTE: These can be problematic if the file does not already exists in
      # the persist location as in that case they will symlink instead of bind
      # mounting. May need manual setup by copying generated cache file to
      # persist.
      ".cache/radv_builtin_shaders32"
      ".cache/radv_builtin_shaders64"
    ];
  };
}
