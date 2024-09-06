{
  ns,
  lib,
  config,
  ...
}:
let
  inherit (lib) mkEnableOption mkDefault;
in
{
  imports = lib.${ns}.scanPaths ./.;

  options.${ns}.hardware.graphics = {
    hardwareAcceleration = mkEnableOption ''
      Enable hardware acceleration. Useful for headless systems that need to
      perform hardware accelerated rendering.
    '';
  };

  config =
    let
      cfg = config.${ns}.hardware.graphics;
    in
    {
      hardware.graphics.enable = mkDefault cfg.hardwareAcceleration;
    };
}
