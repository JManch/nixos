{ config, inputs, username, ... }:
{
  imports = with inputs; [
    agenix.homeManagerModules.default
    nix-resources.homeManagerModules.secrets
  ];

  age.identityPaths = [ "${config.home.homeDirectory}/.ssh/${username}_ed25519" ];
}
