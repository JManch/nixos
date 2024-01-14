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

  # This overlay just adds the linux-x86_64 matlab packages to pkgs
  nixpkgs.overlays = [ inputs.nix-matlab.overlay ];

  environment.systemPackages = with pkgs; [
    matlab
  ];

  environment.persistence."/persist".users.${username} = {
    directories = [
      ".config/matlab"
    ];
  };
}
