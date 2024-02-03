{ lib, ... }:
let
  inherit (lib) mkEnableOption;
in
{
  imports = lib.utils.scanPaths ./.;

  options.modules.shell = {
    enable = mkEnableOption "enable custom shell";
  };
}
