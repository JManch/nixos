{ lib, ... }@args:
{
  imports = (
    lib.${lib.ns}.importCategories {
      inherit args;
      rootDir = ./.;
      isHomeManager = true;
    }
  );
}
