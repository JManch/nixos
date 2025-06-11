{
  lib,
  cfg,
  config,
}:
let
  inherit (lib)
    ns
    mkOption
    types
    flatten
    mapAttrs'
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
    optionalString
    mapAttrs
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
      (all (oPath: elem oPath backup.paths || any (path: hasPrefix oPath path) backup.paths) (
        attrNames backup.restore.pathOwnership
      ))
      "Backup ${name} defines `pathOwnership` paths that are not a part of the backup paths"
      (all (
        path: hasPrefix "/" path && stringLength path > 1 && (impermanence.enable -> path != "/persist")
      ) backup.paths)
      "Backup ${name} contains invalid backup paths"
      cfg.${backup.backend}.enable
      "Backup ${name} uses backend '${backup.backend}' but the backend is not enabled on the host"
    ]) cfg.backups
  );

  opts = {
    backends = mkOption {
      type = with types; attrsOf (functionTo attrs);
      internal = true;
      default = { };
      description = ''
        Attribute set of backends where the value is a function that accepts
        the set of arguments passed to the backup's submodule and returns an
        attribute passed to types.submodule for the backend's `extraOptions`
        option.

        The backend name must match the backend's module name.
      '';
    };

    backups = import ./backups-option.nix lib cfg // {
      apply =
        backups:
        let
          homeIntersection = intersectAttrs backups homeBackups;
        in
        assert assertMsg (homeIntersection == { })
          "The following backups are defined in both Home Manager and NixOS: ${concatStringsSep ", " (attrNames homeIntersection)}";
        mapAttrs (
          _: backup:
          backup
          // {
            paths = map (path: optionalString impermanence.enable "/persist" + path) backup.paths;
            restore = backup.restore // {
              pathOwnership = mapAttrs' (
                path: value: nameValuePair (optionalString impermanence.enable "/persist" + path) value
              ) backup.restore.pathOwnership;
            };
          }
        ) (backups // homeBackups);
    };
  };
}
