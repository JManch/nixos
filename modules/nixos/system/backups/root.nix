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
    concatMapStringsSep
    concatStringsSep
    singleton
    mkAliasOptionModule
    nameValuePair
    all
    getExe
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
      "Backups `ssidBlacklist` only supports systemd-networkd"
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

  systemd.services = mapAttrs' (
    name: value:
    let
      unitName = "${value.backend}-backups-${name}";
      retryUnit = "retry-${unitName}";
      ssidCheck = pkgs.writeShellApplication {
        name = "backup-ssid-check-${unitName}";
        runtimeInputs = with pkgs; [
          coreutils
          systemd
          jaq
          iproute2
        ];
        text = ''
          iface="${networking.wireless.interface}"

          # Schedule a retry in 30 mins
          skip() {
            echo "$1"
            systemctl stop "${retryUnit}.timer" "${retryUnit}.service" &>/dev/null || true
            if ! systemd-run --quiet --collect \
                   --on-active="30m" \
                   --unit="${retryUnit}" \
                   --description="Retry ${unitName} after a skipped backup" \
                   systemctl start --no-block "${unitName}.service"; then
              echo "WARNING: could not schedule retry for ${unitName}"
            fi
            exit 1
          }

          default_dev=$(ip -json route show default | jaq -r '.[0].dev // ""')
          if [[ -z "$default_dev" ]]; then
            skip "No default route, skipping backup"
          fi
          if [[ "$default_dev" != "$iface" ]]; then
            echo "Default route is via $default_dev, SSID check not applicable"
            exit 0
          fi

          status=$(networkctl status "$iface" --json=short)
          oper=$(jaq -r '.OperationalState // ""' <<<"$status")
          active_ssid=$(jaq -r '.SSID // ""' <<<"$status")

          if [[ "$oper" != "routable" ]]; then
            skip "Interface $iface is '$oper' rather than routable, skipping backup"
          fi
          if [[ -z "$active_ssid" ]]; then
            skip "Could not determine SSID for $iface, skipping backup out of caution"
          fi

          blacklist=(${concatMapStringsSep " " (ssid: "\"${ssid}\"") cfg.ssidBlacklist})
          for ssid in "''${blacklist[@]}"; do
            if [[ "$ssid" == "$active_ssid" ]]; then
              skip "Active SSID is blacklisted from performing backups"
            fi
          done
        '';
      };
    in
    nameValuePair unitName (
      mkIf cfg.${value.backend}.enable {
        wants = [ "network-online.target" ];
        requires = value.dependencies;
        after = value.dependencies ++ [ "network-online.target" ];
        restartIfChanged = false;
        preStart = mkOrder 0 ''
          ${value.preBackupScript}
        '';
        postStop = mkOrder 2000 ''
          ${value.postBackupScript}
        '';
        unitConfig = {
          StartLimitIntervalSec = "2h";
          StartLimitBurst = 4;
        };
        serviceConfig = {
          # If the SSID check fails the remaining service commands are skipped and
          # the unit is NOT marked as failed, so OnFailure notifications don't fire
          # for a routine skip.
          ExecCondition = mkIf (cfg.ssidBlacklist != [ ]) "${getExe ssidCheck}";
          # Cancel any pending retries
          ExecStartPost = mkIf (
            cfg.ssidBlacklist != [ ]
          ) "-${pkgs.systemd}/bin/systemctl stop ${retryUnit}.timer ${retryUnit}.service";
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

  systemd.timers = mapAttrs' (
    name: backup:
    nameValuePair "${backup.backend}-backups-${name}" (
      mkIf (cfg.${backup.backend}.enable && backup.timerConfig != null) {
        inherit (backup) timerConfig;
        enable = !inputs.firstBoot.value;
        wantedBy = [ "timers.target" ];
        unitConfig.X-OnlyManualStart = true;
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
