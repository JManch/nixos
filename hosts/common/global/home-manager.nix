{
  inputs,
  username,
  hostname,
  ...
}: {
  imports = [
    inputs.home-manager.nixosModules.home-manager
  ];

  home-manager = {
    extraSpecialArgs = {inherit inputs username hostname;};
    useGlobalPkgs = true;
    useUserPackages = true;
    users = {
      ${username} = import ../../../home/${hostname}.nix;
    };
  };
}
