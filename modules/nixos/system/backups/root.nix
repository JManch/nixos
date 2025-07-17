{
  lib,
  cfg,
  args,
  pkgs,
  config,
  inputs,
}:
let
  inherit (lib)
    ns
    mkOption
    types
    flatten
    mapAttrs'
    mkOrder
    mkIf
    toUpper
    intersectAttrs
    assertMsg
    any
    optionalString
    concatMapStringsSep
    concatStringsSep
    singleton
    mkAliasOptionModule
    nameValuePair
    all
    getExe
    getExe'
    mapAttrsToList
    stringLength
    elem
    hasPrefix
    attrNames
    optionalAttrs
    ;
  inherit (config.${ns}.core) home-manager;
  inherit (config.${ns}.system) impermanence networking;
  inherit (config.${ns}.system) virtualisation;
  homeBackups = optionalAttrs home-manager.enable config.${ns}.hmNs.backups;
in
{
  exclude = [ "backups-option.nix" ];

  imports = singleton (
    mkAliasOptionModule
      [ ns "backups" ]
      [
        ns
        "system"
        "backups"
        "backups"
      ]
  );

  asserts =
    flatten (
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
        (backup.isHome -> backup.restore.pathOwnership == { })
        "Home backup '${name}' uses unsupported option `pathOwnership`"
      ]) cfg.backups
    )
    ++ [
      (cfg.ssidBlacklist != [ ] -> networking.wireless.enable)
      "Backups `ssidBlacklist` requires wireless to be enabled"
      (cfg.ssidBlacklist != [ ] -> networking.useNetworkd)
      "Backups `ssidBlacklist` only support wpa-supplicant with systemd-networkd"
    ];

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
        if inputs.vmInstall.value || virtualisation.vmVariant then
          { }
        else
          assert assertMsg (homeIntersection == { })
            "The following backups are defined in both Home Manager and NixOS: ${concatStringsSep ", " (attrNames homeIntersection)}";
          backups // homeBackups;
    };

    ssidBlacklist = mkOption {
      type = with types; listOf str;
      default = [ ];
      description = ''
        Blacklist of SSIDs to not perform backups on.
      '';
    };
  };

  # only check ssid blacklist if wired interface is down
  systemd.services =
    let
      ssidCheck = pkgs.writeShellScript "backup-ssid-check" ''
        active_ssid=$(${getExe' pkgs.wpa_supplicant "wpa_cli"} status | ${getExe pkgs.gnugrep} '^ssid=' | ${getExe' pkgs.coreutils "cut"} -d'=' -f2)
        blacklist=(${concatMapStringsSep " " (ssid: "\"${ssid}\"") cfg.ssidBlacklist})
        for ssid in "''${blacklist[@]}"; do
          if [[ $ssid == $active_ssid ]]; then
            echo "Active SSID is blacklisted from performing backups"
            exit 1
          fi
        done
      '';
    in
    mapAttrs' (
      name: value:
      nameValuePair "${value.backend}-backups-${name}" (
        mkIf cfg.${value.backend}.enable {
          preStart = mkOrder 0 ''
            ${optionalString (cfg.ssidBlacklist != [ ]) ssidCheck.outPath}
            ${value.preBackupScript}
          '';

          postStop = mkOrder 2000 ''
            ${value.postBackupScript}
          '';

          unitConfig = {
            StartLimitBurst = 4;
            StartLimitIntervalSec = "2h";
          };

          serviceConfig = {
            Restart = "on-failure";
            RestartSec = "5m";
            RestartMaxDelaySec = "30m";
            RestartSteps = 3;

            ProtectSystem = "strict";
            ProtectHome = "read-only";
          };
        }
      )
    ) cfg.backups;

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
