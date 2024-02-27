{ lib
, pkgs
, config
, ...
}:
let
  inherit (lib) mkIf mkBefore;
  inherit (config.device) gpu;

  amdgpu_top = pkgs.amdgpu_top.overrideAttrs (oldAttrs: {
    postInstall = oldAttrs.postInstall + /*bash*/ ''
      substituteInPlace $out/share/applications/amdgpu_top.desktop \
        --replace "Name=AMDGPU TOP (GUI)" "Name=AMDGPU Top"
    '';
  });
in
mkIf (gpu.type == "amd")
{
  boot.initrd.kernelModules = mkBefore [ "amdgpu" ];
  environment.systemPackages = [ amdgpu_top ];
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

  persistenceHome = {
    directories = [
      ".cache/AMD"
      ".cache/mesa_shader_cache"
    ];

    files = [
      ".cache/radv_builtin_shaders32"
      ".cache/radv_builtin_shaders64"
    ];
  };
}
