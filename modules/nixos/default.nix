{ lib, ... }@args:
{
  imports =
    [
      ./core
      ./system
      ./hardware
      ./services
    ]
    ++ (lib.${lib.ns}.importCategories {
      inherit args;
      rootDir = ./.;
      exclude = [
        "core"
        "system"
        "hardware"
        "services"
      ];
    });
}
