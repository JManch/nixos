{ lib, args }:
{
  # Install instructions: https://gitlab.com/doronbehar/nix-matlab
  ns.userPackages = [ (lib.${lib.ns}.flakePkgs args "nix-matlab").matlab ];

  ns.persistenceHome.directories = [ ".config/matlab" ];
}
