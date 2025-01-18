{ lib, ... }:
{
  imports = lib.${lib.ns}.scanPaths ./.;
}
