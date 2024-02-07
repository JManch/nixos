{ inputs, ... }:
{
  imports = [
    inputs.nix-resources.nixosModules.caddy
  ];
}
