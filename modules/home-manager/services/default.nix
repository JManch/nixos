{ lib, ... }:
let
  inherit (lib) mkEnableOption;
in
{
  imports = lib.utils.scanPaths ./.;

  options.modules.services = {
    syncthing.enable = mkEnableOption "Syncthing";
    easyeffects.enable = mkEnableOption "Easyeffects";
  };
}
