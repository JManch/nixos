{ lib
, pkgs
, config
, username
, ...
}:
let
  inherit (lib) mkIf mkBefore;
  amd = config.device.gpu.type == "amd";
in
mkIf amd
{
  boot.initrd.kernelModules = mkBefore [ "amdgpu" ];
  environment.systemPackages = [ pkgs.amdgpu_top ];
  services.xserver.videoDrivers = [ "modesetting" ];

  # Make radv the default driver
  environment.sessionVariables.AMD_VULKAN_ICD = "RADV";

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

  programs.corectrl = {
    enable = true;
    # WARN: Disable this if you experience flickering or general instability
    # https://wiki.archlinux.org/title/AMDGPU#Boot_parameter
    gpuOverclock.enable = true;
    gpuOverclock.ppfeaturemask = "0xffffffff";
  };

  users.users.${username}.extraGroups = [ "corectrl" ];

  persistenceHome = {
    directories = [
      ".cache/AMD"
      ".cache/mesa_shader_cache"
      ".config/corectrl"
    ];
    files = [
      ".cache/radv_builtin_shaders32"
      ".cache/radv_builtin_shaders64"
    ];
  };
}
