{ lib, config, ... }:
let
  inherit (lib) utils mkEnableOption mkDefault;
in
{
  imports = utils.scanPaths ./.;

  options.modules.hardware.graphics = {
    hardwareAcceleration = mkEnableOption ''
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
      hardware.opengl.enable = mkDefault cfg.hardwareAcceleration;
    };
}
