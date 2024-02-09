{ lib, ... }:
let
  inherit (lib) mkEnableOption;
in
{
  imports = lib.utils.scanPaths ./.;

  options.modules.programs = {
    winbox.enable = mkEnableOption "winbox";
    wine.enable = mkEnableOption "wine";
    matlab.enable = mkEnableOption "matlab";
  };
}
