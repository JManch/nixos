{ lib, config, ... }:
let
  inherit (lib) utils mkEnableOption mkDefault;
in
{
  imports = utils.scanPaths ./.;

  options.modules.hardware.graphics = {
    hardwareAcceleration = mkEnableOption ''
      Enable hardware acceleration. Useful for headless systems that need to
      perform hardware accelerated rendering.
    '';
  };

  config =
    let
      cfg = config.modules.hardware.graphics;
    in
    {
      hardware.graphics.enable = mkDefault cfg.hardwareAcceleration;
    };
}
