{ lib, ... }@args:
{
  imports =
    [
      ./services
    ]
    ++ (lib.${lib.ns}.importCategories {
      inherit args;
      rootDir = ./.;
      exclude = [
        "services"
      ];
    });
}
