{
  lib,
  pkgs,
  osConfig,
}:
let
  inherit (lib) getExe' optionalString;
  hyprctl = getExe' pkgs.hyprland "hyprctl";
  hasFingerprint = osConfig.services.fprintd.enable;
in
{
  categoryConfig.locker = {
    package = pkgs.waylock;

    defaultArgs = [ ];

    postUnlockScript = optionalString hasFingerprint "${hyprctl} dispatch dpms on";
  };
}
