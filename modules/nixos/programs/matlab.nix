{
  ns,
  lib,
  config,
  ...
}@args:
let
  cfg = config.${ns}.programs.matlab;
in
lib.mkIf cfg.enable {
  # Install instructions: https://gitlab.com/doronbehar/nix-matlab
  userPackages = [ (lib.${ns}.flakePkgs args "nix-matlab").matlab ];

  persistenceHome.directories = [ ".config/matlab" ];
}
