{ lib, ... }:
{
  imports = lib.utils.scanPaths ./.;
}
