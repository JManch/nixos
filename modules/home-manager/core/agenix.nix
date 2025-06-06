{ config, inputs }:
{
  enableOpt = false;

  imports = with inputs; [
    agenix.homeManagerModules.default
    nix-resources.homeManagerModules.secrets
  ];

  age.identityPaths = [ "${config.home.homeDirectory}/.ssh/agenix_ed25519_key" ];
}
