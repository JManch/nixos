{ inputs, pkgs, ... }:
let
  inherit (inputs) agenix nix-resources;
in
{
  imports = [
    agenix.nixosModules.default
    nix-resources.nixosModules.secrets
  ];

  environment.systemPackages = [
    agenix.packages.${pkgs.system}.default
  ];

  # Agenix decrypts before impermanence creates mounts so we have to get key
  # from persist
  age.identityPaths = [ "/persist/etc/ssh/ssh_host_ed25519_key" ];
}
