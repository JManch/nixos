{ ns, lib, ... }:
{
  imports = lib.${ns}.scanPaths ./.;
}
