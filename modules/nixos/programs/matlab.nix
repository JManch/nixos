{ lib
, pkgs
, inputs
, config
, username
, ...
}:
let
  cfg = config.modules.programs.matlab;
in
lib.mkIf cfg.enable
{
  # Follow install instructions here https://gitlab.com/doronbehar/nix-matlab
  nixpkgs.overlays = [ inputs.nix-matlab.overlay ];

  # environment.systemPackages = [
  #   inputs.nix-matlab.packages.${pkgs.system}.default
  # ];

  environment.persistence."/persist".users.${username} = {
    directories = [
      ".config/matlab"
    ];
  };
}
