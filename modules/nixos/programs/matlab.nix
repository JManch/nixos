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

  # This overlay just adds the matlab packages to the system packages
  nixpkgs.overlays = [ inputs.nix-matlab.overlay ];

  environment.systemPackages = with pkgs; [
    matlab
    matlab-shell
  ];

  environment.persistence."/persist".users.${username} = {
    directories = [
      ".config/matlab"
    ];
  };
}
