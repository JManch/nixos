{ inputs
, config
, username
, hostname
, lib
, ...
}: {
  imports = [
    inputs.home-manager.nixosModules.home-manager
  ];

  config = lib.mkIf config.usrEnv.homeManager.enable {
    home-manager = {
      extraSpecialArgs = { inherit inputs username hostname; osConfig = config; };
      useGlobalPkgs = true;
      useUserPackages = true;
      users = {
        ${username} = import ../../../home/${hostname}.nix;
      };
    };
  };
}
