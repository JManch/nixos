{
  lib,
  cfg,
  args,
  config,
}:
let
  inherit (lib)
    ns
    mkOption
    types
    flatten
    mapAttrs'
    mkIf
    toUpper
    intersectAttrs
    assertMsg
    any
    concatStringsSep
    singleton
    mkAliasOptionModule
    nameValuePair
    all
    mapAttrsToList
    stringLength
    elem
    hasPrefix
    attrNames
    optionalAttrs
    ;
  inherit (config.${ns}.core) home-manager;
  inherit (config.${ns}.system) impermanence;
  homeBackups = optionalAttrs home-manager.enable config.${ns}.hmNs.backups;
in
{
  exclude = [ "backups-option.nix" ];

  imports = singleton (
    mkAliasOptionModule
      [ ns "backups" ]
      [
        ns
        "services"
        "backups"
        "backups"
      ]
  );

  asserts = flatten (
    mapAttrsToList (name: backup: [
      (backup.paths != [ ])
      "Backup '${name}' does not define any backup paths"
      (all (oPath: elem oPath backup.paths || any (path: hasPrefix oPath path) backup.paths) (
        attrNames backup.restore.pathOwnership
      ))
      "Backup '${name}' defines `pathOwnership` paths that are not a part of the backup paths"
      (all (
        path: hasPrefix "/" path && stringLength path > 1 && (impermanence.enable -> path != "/persist")
      ) backup.paths)
      "Backup '${name}' contains invalid backup paths"
      cfg.${backup.backend}.enable
      "Backup '${name}' uses backend '${backup.backend}' but the backend is not enabled on the host"
      (backup.isHome -> backup.restore.pathOwnership == { })
      "Home backup '${name}' uses unsupported option `pathOwnership`"
    ]) cfg.backups
  );

  opts = {
    backends = mkOption {
      type = with types; attrsOf (functionTo attrs);
      internal = true;
      default = { };
      description = ''
        Attribute set of backends where the value is a function that accepts the set of
        arguments passed to the backup's submodule and returns an attribute set passed
        to types.submodule for the backend's `backendOptions` option.

        The backend name must match the backend's module name.
      '';
    };

    backups = import ./backups-option.nix args cfg false // {
      apply =
        backups:
        let
          homeIntersection = intersectAttrs backups homeBackups;
        in
        assert assertMsg (homeIntersection == { })
          "The following backups are defined in both Home Manager and NixOS: ${concatStringsSep ", " (attrNames homeIntersection)}";
        backups // homeBackups;
    };
  };

  ns.services =
    let
      createNotifyServices = type: {
        "${type}NotifyServices" = mapAttrs' (
          name: backup:
          nameValuePair "${backup.backend}-backups-${name}" (
            mkIf (cfg.${backup.backend}.enable && backup.notifications.${type}.enable) (
              {
                discord.enable = true;
                discord.var = toUpper backup.backend;
              }
              // backup.notifications.${type}.config
            )
          )
        ) cfg.backups;
      };
    in
    createNotifyServices "success"
    // createNotifyServices "failure"
    // {
      healthCheckServices = mapAttrs' (
        name: backup:
        let
          healthCheckCfg = backup.notifications.healthCheck;
        in
        nameValuePair "${backup.backend}-backups-${name}" (
          mkIf (cfg.${backup.backend}.enable && healthCheckCfg.enable) {
            var = mkIf (healthCheckCfg.var != null) healthCheckCfg.var;
          }
        )
      ) cfg.backups;
    };
}
