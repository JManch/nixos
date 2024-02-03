{ lib, ... }:
{
  imports = lib.utils.scanPaths ./.;

  options.modules.shell = {
    enable = lib.mkEnableOption "enable custom shell";
  };
}
