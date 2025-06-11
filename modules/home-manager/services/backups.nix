{
  lib,
  config,
  osConfig,
}:
let
  inherit (lib)
    ns
    singleton
    mkAliasOptionModule
    mapAttrs
    ;
in
{
  enableOpt = false;

  imports = singleton (
    mkAliasOptionModule
      [ ns "backups" ]
      [
        ns
        "services"
        "backups"
      ]
  );

  opts =
    import ../../nixos/services/backups/backups-option.nix lib osConfig.${lib.ns}.services.backups
    // {
      apply =
        backups:
        mapAttrs (
          name: backup:
          backup
          // {
            paths = map (path: "${config.home.homeDirectory}/${path}") backup.paths;
          }
        ) backups;
    };
}
