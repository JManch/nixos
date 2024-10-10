{
  ns,
  lib,
  config,
  inputs,
  ...
}:
let
  cfg = config.${ns}.programs.davinci-resolve;
in
{
  imports = [ inputs.nix-resources.homeManagerModules.davinci-resolve-studio ];

  config = lib.mkIf cfg.enable {
    persistence.directories = [ ".local/share/DaVinciResolve" ];
  };
}
