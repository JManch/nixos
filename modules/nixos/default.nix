{ lib, ... }@args:
{
  imports =
    [
      ./system
      ./services
    ]
    ++ (lib.${lib.ns}.importCategories {
      inherit args;
      rootDir = ./.;
      exclude = [
        "system"
        "services"
      ];
    });
}
