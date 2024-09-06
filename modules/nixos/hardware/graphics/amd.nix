{
  ns,
  lib,
  pkgs,
  config,
  ...
}:
let
  inherit (lib) mkIf mkBefore;

  amdgpu_top = pkgs.amdgpu_top.overrideAttrs (oldAttrs: {
    postInstall =
      oldAttrs.postInstall
      # bash
      + ''
        substituteInPlace $out/share/applications/amdgpu_top.desktop \
          --replace "Name=AMDGPU TOP (GUI)" "Name=AMDGPU Top"
      '';
  });
in
mkIf (config.${ns}.device.gpu.type == "amd") {
  boot.initrd.kernelModules = mkBefore [ "amdgpu" ];
  userPackages = [ amdgpu_top ];
  services.xserver.videoDrivers = [ "modesetting" ];

  # TODO: Use hardware.amdgpu option when I update my flake

  # Make radv the default driver
  environment.sessionVariables.AMD_VULKAN_ICD = "RADV";

  # There are two main AMD user drivers: AMDVLK and RADV. AMDVLK is the offical
  # open source driver provided by AMD whilst RADV is made by Valve. Depending
  # on the application, one may perform better than the other so it's useful to
  # have both installed and toggle between them. RADV is installed as part of
  # the Mesa driver package which is installed when hardware.opengl.driSupport is
  # enabled. AMDVLK is installed through the extraPackages option. There is also
  # the kernel module driver component which is amdgpu.
  hardware.graphics.enable = true;

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
