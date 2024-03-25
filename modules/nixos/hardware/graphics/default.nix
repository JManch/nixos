{ lib, config, ... }:
{
  imports = lib.utils.scanPaths ./.;

  options.modules.hardware.graphics = {
    hardwareAcceleration = lib.mkEnableOption ''
      Enable hardware acceleration regardless of whether or not the system has
      a dedicated GPU. Useful for headless systems without dedicated GPUs or
      graphical environments.
    '';
  };

  config =
    let
      cfg = config.modules.hardware.graphics;
    in
    {
      hardware.opengl.enable = cfg.hardwareAcceleration;
    };
}
