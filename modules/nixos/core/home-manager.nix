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
    (lib.mkAliasOptionModule [ "hm" ] [ "home-manager" "users" username ])
  ];

  config = lib.mkIf cfg.enable {
    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      users.${username} = import ../../../home/${hostname}.nix;
      sharedModules = [ ../../home-manager ];

      extraSpecialArgs = {
        inherit inputs outputs username hostname;
        vmVariant = false;
      };
    };

    virtualisation.vmVariant = {
      home-manager.extraSpecialArgs = { vmVariant = true; };
    };
  };
}
