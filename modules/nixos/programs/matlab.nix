{ lib, args }:
{
  # Install instructions: https://gitlab.com/doronbehar/nix-matlab
  userPackages = [ (lib.${lib.ns}.flakePkgs args "nix-matlab").matlab ];

  ns.persistenceHome.directories = [ ".config/matlab" ];
}
