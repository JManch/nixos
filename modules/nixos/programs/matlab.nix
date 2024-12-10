{ lib, config, ... }@args:
let
  cfg = config.${lib.ns}.programs.matlab;
in
lib.mkIf cfg.enable {
  # Install instructions: https://gitlab.com/doronbehar/nix-matlab
  userPackages = [ (lib.${lib.ns}.flakePkgs args "nix-matlab").matlab ];

  persistenceHome.directories = [ ".config/matlab" ];
}
