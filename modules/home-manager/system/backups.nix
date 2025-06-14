{
  lib,
  args,
  osConfig,
}:
let
  inherit (lib)
    ns
    singleton
    mkAliasOptionModule
    ;
in
{
  enableOpt = false;

  imports = singleton (
    mkAliasOptionModule
      [ ns "backups" ]
      [
        ns
        "system"
        "backups"
      ]
  );

  opts =
    import ../../nixos/system/backups/backups-option.nix args osConfig.${lib.ns}.system.backups
      true;
}
