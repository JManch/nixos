{ lib
, inputs
, config
, outputs
, username
, hostname
, ...
}: {
  imports = [
    inputs.home-manager.nixosModules.home-manager
  ];

  config = lib.mkIf config.usrEnv.homeManager.enable {
    home-manager = {
      extraSpecialArgs = { inherit inputs outputs username hostname; };
      useGlobalPkgs = true;
      useUserPackages = true;
      users = {
        ${username} = import ../../../home/${hostname}.nix;
      };
    };
  };
}
