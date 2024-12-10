{ lib, config, ... }:
let
  inherit (lib)
    ns
    mkEnableOption
    types
    mkOption
    mkDefault
    ;
in
{
  imports = lib.${ns}.scanPathsExcept ./. [ "amdgpu-kernel-module.nix" ];

  options.${ns}.hardware.graphics = {
    hardwareAcceleration = mkEnableOption ''
      Enable hardware acceleration. Useful for headless systems that need to
      perform hardware accelerated rendering.
    '';

    amd.kernelPatches = mkOption {
      type = with types; listOf path;
      default = [ ];
      description = ''
        List of patches to apply to the amdgpu kernel module. Waiting for this
        to get implemented upstream https://github.com/NixOS/nixpkgs/pull/321663.
      '';
    };
  };

  config =
    let
      cfg = config.${ns}.hardware.graphics;
    in
    {
      hardware.graphics.enable = mkDefault cfg.hardwareAcceleration;
    };
}
