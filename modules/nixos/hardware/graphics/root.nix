{ lib, cfg }:
{
  exclude = [ "amdgpu-kernel-module.nix" ];

  opts.hardwareAcceleration = lib.mkEnableOption ''
    Enable hardware acceleration. Useful for headless systems that need to
    perform hardware accelerated rendering.
  '';

  hardware.graphics.enable = lib.mkDefault cfg.hardwareAcceleration;
}
