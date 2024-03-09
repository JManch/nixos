{ inputs, pkgs, ... }:
{
  imports = [
    inputs.agenix.nixosModules.default
    inputs.nix-resources.nixosModules.secrets
  ];

  environment.systemPackages = [
    inputs.agenix.packages.${pkgs.system}.default
  ];
}
