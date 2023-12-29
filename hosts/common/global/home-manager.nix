{ inputs
, config
, username
, hostname
, ...
}: {
  imports = [
    inputs.home-manager.nixosModules.home-manager
  ];

  home-manager = {
    extraSpecialArgs = { inherit inputs username hostname; osConfig = config; };
    useGlobalPkgs = true;
    useUserPackages = true;
    users = {
      ${username} = import ../../../home/${hostname}.nix;
    };
  };
}
