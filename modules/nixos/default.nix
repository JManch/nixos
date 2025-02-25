{ lib, ... }@args:
{
  imports =
    [
      ./core
      ./system
      ./services
    ]
    ++ (lib.${lib.ns}.importCategories {
      inherit args;
      rootDir = ./.;
      exclude = [
        "core"
        "system"
        "services"
      ];
    });
}
