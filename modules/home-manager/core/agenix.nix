{ config, inputs, username, ... }:
{
  imports = [
    inputs.agenix.homeManagerModules.default
  ];

  age.identityPaths = [ "${config.home.homeDirectory}/.ssh/${username}_ed25519" ];
}
