{ lib
, pkgs
, inputs
, config
, ...
}:
let
  inherit (lib) mkIf utils;
  cfg = config.modules.programs.matlab;
in
mkIf cfg.enable
{
  # Install instructions: https://gitlab.com/doronbehar/nix-matlab
  environment.systemPackages = [
    (utils.flakePkgs { inherit pkgs inputs; } "nix-matlab").matlab
  ];

  persistenceHome.directories = [ ".config/matlab" ];
}
