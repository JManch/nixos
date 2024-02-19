{ lib
, pkgs
, inputs
, config
, ...
}:
let
  cfg = config.modules.programs.matlab;
in
lib.mkIf cfg.enable
{
  # Install instructions: https://gitlab.com/doronbehar/nix-matlab

  # This overlay just adds the linux-x86_64 matlab packages to pkgs
  nixpkgs.overlays = [ inputs.nix-matlab.overlay ];

  environment.systemPackages = [ pkgs.matlab ];

  persistenceHome.directories = [ ".config/matlab" ];
}
