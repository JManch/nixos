{
  inputs,
  config,
  username,
  ...
}: {
  imports = [
    inputs.home-manager.nixosModules.home-manager
  ];

  home-manager = let
    hostname = config.networking.hostName;
  in {
    extraSpecialArgs = {inherit inputs username hostname;};
    useGlobalPkgs = true;
    useUserPackages = true;
    users = {
      ${username} = import ../../../home/${hostname}.nix;
    };
  };
}
