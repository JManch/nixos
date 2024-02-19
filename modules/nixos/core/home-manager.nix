{ lib
, inputs
, config
, outputs
, username
, hostname
, ...
}:
let
  cfg = config.usrEnv.homeManager;
in
{
  imports = [
    inputs.home-manager.nixosModules.home-manager
  ];

  config = lib.mkIf cfg.enable {
    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      users.${username} = import ../../../home/${hostname}.nix;

      extraSpecialArgs = {
        inherit inputs outputs username hostname;
        vmVariant = false;
      };
    };
  };
}
