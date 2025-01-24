{ config, inputs }:
let
  inherit (config.home) homeDirectory username;
in
{
  enableOpt = false;

  imports = with inputs; [
    agenix.homeManagerModules.default
    nix-resources.homeManagerModules.secrets
  ];

  age.identityPaths = [ "${homeDirectory}/.ssh/${username}_ed25519" ];
}
