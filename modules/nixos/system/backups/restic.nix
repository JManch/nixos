{
  lib,
  cfg,
  pkgs,
  self,
  utils,
  config,
  inputs,
  hostname,
  categoryCfg,
}:
let
  inherit (lib)
    ns
    mkIf
    mkMerge
    mkForce
    filterAttrs
    mapAttrsToList
    getExe
    concatStrings
    concatStringsSep
    concatMapStrings
    concatMapStringsSep
    nameValuePair
    optionals
    optional
    mapAttrs'
    attrNames
    singleton
    optionalString
    mkOption
    mkEnableOption
    types
    ;
  inherit (config.${ns}.system) virtualisation;
  inherit (config.${ns}.services.caddy) trustedAddresses;
  inherit (config.age.secrets)
    resticPasswordFile
    resticHtPasswordsFile
    resticRepositoryFile
    resticReadWriteBackblazeVars
    resticReadOnlyBackblazeVars
    ;
  resticExe = getExe pkgs.restic;
  backups = filterAttrs (_: backup: backup.backend == "restic") categoryCfg.backups;
  cacheDir = "/var/cache/restic";

  pruneOpts = [
    "--keep-daily 7"
    "--keep-weekly 4"
    "--keep-monthly 6"
    "--keep-yearly 3"
  ];

  failureCfg = {
    discord.enable = true;
    discord.var = "RESTIC";
  };

  restoreScript = pkgs.writeShellApplication {
    name = "restic-restore";
    runtimeInputs = with pkgs; [
      restic
      coreutils
      systemd
      bash
    ];
    text = ''
      echo "Leave empty to restore from the default repo"
      echo "Enter 'remote' to restore from the backblaze remote repo"
      echo "Otherwise, enter a custom repo passed to the -r flag"
      read -p "Enter the repo to restore from: " -r repo

      case "$repo" in
        remote) restic_cmd=( sudo ${getExe (resticRemote true)} ) ;;
        "")     restic_cmd=( sudo restic --cache-dir ${cacheDir} --password-file ${resticPasswordFile.path} --repository-file ${resticRepositoryFile.path} ) ;;
        *)      restic_cmd=( sudo restic --cache-dir ${cacheDir} --repo "$repo" ) ;;
      esac

      "''${restic_cmd[@]}" snapshots --compact --no-lock --group-by tags

      read -p "Do you want to proceed with this repo? (y/N): " -n 1 -r
      if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then echo "Aborting"; exit 1; fi
      echo

      read -p "Enter the host to restore from (leave empty for current): " -r hostname
      if [ -z "$hostname" ]; then hostname="${hostname}"; fi

      foreign_host=false
      if [ "$hostname" != "${hostname}" ]; then
        foreign_host=true
      fi

      ${concatMapStrings (
        hostname:
        concatStrings (
          mapAttrsToList (
            name: value: # bash
            ''
              if [ "$hostname" = "${hostname}" ]; then
              read -p "Restore backup ${name}? (y/N): " -n 1 -r
              if [[ "$REPLY" =~ ^[Yy]$ ]]; then
                echo
                "''${restic_cmd[@]}" snapshots --tag ${name} --host ${hostname} --no-lock
                read -p "Enter the snapshot ID to restore (leave empty for latest): " -r snapshot
                if [ -z "$snapshot" ]; then snapshot="latest"; fi

                target="/"
                custom_target=false
                if [ "$foreign_host" = false ]; then
                  read -p "Would you like to restore to a custom path instead of the original? Restore scripts will NOT run. (y/N): " -n 1 -r
                else
                  echo -n "WARN: Since you are restoring a foreign host you must specify a restore path and restore scripts will NOT run"
                fi
                if [[ "$foreign_host" = true || "$REPLY" =~ ^[Yy]$ ]]; then
                  echo
                  read -p "Enter an absolute path to a restore directory: " -r target
                  if [[ -z "$target" || -e "$target" ]]; then
                    echo "Invalid path, make sure it does not already exist" >&2
                    exit 1
                  fi
                  mkdir -p "$target"
                  custom_target=true
                fi

                echo "Restoring snapshot $snapshot to $target..."

                restore_snapshot() {
                  echo "Restoring snapshot..."
                  "''${restic_cmd[@]}" restore "$snapshot" --target "$target" --verify --tag ${name} --host ${hostname} --no-lock
                }

                restore_ownership() {
                  echo "Restoring ownership..."
                  # Update ownership because UID/GID mappings are not guaranteed to match between hosts
                  # Modules with statically mapped IDs don't need this https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/misc/ids.nix
                  ${concatStrings (
                    mapAttrsToList (
                      path: ownership:
                      let
                        inherit (ownership) user group;
                      in
                      (optionalString (user != null) # bash
                        ''
                          if id -u "${user}" >/dev/null 2>&1; then
                            sudo chown -R ${user} ${path}
                          else
                            echo "Warning: User ownership restore failed. User '${user}' does not exist on the system." >&2
                          fi
                        ''
                      )
                      + (optionalString (group != null) # bash
                        ''
                          if getent group "${group}" >/dev/null 2>&1; then
                            sudo chgrp -R ${group} ${path}
                          else
                            echo "Warning: Group ownership restore failed. Group '${group}' does not exist on the system." >&2
                          fi
                        ''
                      )
                    ) value.restore.pathOwnership
                  )}
                }

                if [ "$custom_target" = true ]; then
                  restore_snapshot
                  restore_ownership
                else
                  read -p "Existing files are about to be replaced by the backup. Are you sure you want to continue? (y/N): " -n 1 -r
                  if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then echo "Aborting"; exit 1; fi
                  echo
                  ${optionalString value.restore.removeExisting (
                    concatMapStringsSep ";" (
                      path: "echo 'Removing existing files in ${path}...';sudo rm -rf ${path}"
                    ) value.paths
                  )}
                  echo "Running pre-restore script..."
                  ${value.restore.preRestoreScript}
                  restore_snapshot
                  restore_ownership
                  echo "Running post-restore script..."
                  ${value.restore.postRestoreScript}
                fi
              fi
              fi
            '') self.nixosConfigurations.${hostname}.config.${ns}.system.backups.backups
        )
      ) (attrNames self.nixosConfigurations)}
    '';
  };

  resticRemote =
    readOnly:
    pkgs.writeShellApplication {
      name = "restic-remote${optionalString readOnly "-ro"}";
      runtimeInputs = [ pkgs.restic ];
      text = ''
        if [ "$(id -u)" -ne 0 ]; then
          echo "restic-remote: must run as root" >&2
          exit 1
        fi

        set -a
        # shellcheck disable=SC1091
        . ${if readOnly then resticReadOnlyBackblazeVars.path else resticReadWriteBackblazeVars.path}
        set +a
        exec restic --cache-dir ${cacheDir} --password-file ${resticPasswordFile.path} "$@"
      '';
    };
in
[
  {
    guardType = "custom";

    categoryConfig.backends.restic = args: {
      options = {
        extraBackupArgs = mkOption {
          type = with types; listOf str;
          default = [ ];
          description = ''
            Extra args passed to the restic backup command.
          '';
        };

        exclude = mkOption {
          type = with types; listOf str;
          default = [ ];
          description = ''
            List of patterns to exclude from the backup. WARN: these are not
            prefixed with persistence root so be careful.
          '';
        };
      };

      config = {
        extraBackupArgs = [
          "--no-scan" # scan is used to estimate backup size for progress indicator
          "--tag"
          args.backupName
        ];
      };
    };

    opts = {
      runMaintenance = mkEnableOption "repo maintenance after performing backups" // {
        default = cfg.server.enable;
      };

      timerConfig = mkOption {
        type = types.attrs;
        default = {
          Persistent = true;
          OnCalendar = "*-*-* 05:30:00";
        };
        description = ''
          Timer config for repo maintainence and default timer config for backups using
          the Restic backend.
        '';
      };

      server = {
        enable = mkEnableOption ''
          storing the Restic repository and serving it through a REST server on
          this host
        '';

        dataDir = mkOption {
          type = types.str;
          description = "Directory where the restic repository is stored";
          default = "/var/backup/restic";
        };

        remoteCopySchedule = mkOption {
          type = types.str;
          default = "*-*-* 05:30:00";
          description = "OnCalendar schedule when local repo is copied to cloud";
        };

        remoteMaintenanceSchedule = mkOption {
          type = types.str;
          default = "Sun *-*-* 06:00:00";
          description = "OnCalendar schedule to perform maintenance on remote repo";
        };

        port = mkOption {
          type = types.port;
          default = 8090;
          description = "Port for the Restic server to listen on";
        };
      };
    };
  }

  (mkIf (cfg.enable || cfg.server.enable) {
    ns.adminPackages = [
      pkgs.restic
      restoreScript
    ];

    systemd.tmpfiles.rules = [ "d ${cacheDir} 0700 root root - -" ];

    # WARN: Always interact with the repository using the REST server, even on
    # the same host. It ensures correct repo file ownership.
    programs.zsh.shellAliases = {
      restic = "sudo restic --cache-dir ${cacheDir} --repository-file ${resticRepositoryFile.path} --password-file ${resticPasswordFile.path}";
      restic-remote = "sudo ${getExe (resticRemote (!cfg.server.enable))}"; # read-only access if we're not the server
      restic-snapshots = "sudo restic snapshots --cache-dir ${cacheDir} --compact --group-by tags --repository-file ${resticRepositoryFile.path} --password-file ${resticPasswordFile.path}";
      restic-restore-size = "sudo restic stats --cache-dir ${cacheDir} --repository-file ${resticRepositoryFile.path} --password-file ${resticPasswordFile.path}";
      restic-repo-size = "sudo restic stats --cache-dir ${cacheDir} --mode raw-data --repository-file ${resticRepositoryFile.path} --password-file ${resticPasswordFile.path}";
      backup-all = concatStringsSep ";" (
        mapAttrsToList (name: _: "sudo systemctl start restic-backups-${name}") backups
      );
    }
    // (mapAttrs' (
      name: _: nameValuePair "backup-${name}" "sudo systemctl start restic-backups-${name}"
    ) backups);

    ns.persistence.directories = singleton {
      directory = cacheDir;
      mode = "0700";
    };

    # Backblaze bucket setup:
    # backblaze-b2 create-bucket --defaultServerSideEncryption=SSE-B2 <bucket_name> --lifecycleRule '{"daysFromHidingToDeleting": 7, "daysFromUploadingToHiding": null, "fileNamePrefix": ""}' allPrivate
    # backblaze-b2 create-key --bucket <bucket_name> restic-copy listBuckets,listFiles,readFiles,writeFiles
    # backblaze-b2 create-key --bucket <bucket_name> restic-read-only listBuckets,listFiles,readFiles

    # For ransomware protection we do not grant the deleteFiles priviledge to
    # the restic-copy key because writeFiles is capable of overwrite existing
    # files. Overrwritten files are 'hidden' for the number of days configured
    # in the lifecycle rule before being permanently deleted. Ideally we would
    # use the 'Object Lock' feature provided by Backblaze but it does not work
    # with Restic. This gives us 7 days after a theoretical attack to restore
    # an old 'snapshot' of the bucket.

    # Restore tool: https://github.com/viltgroup/bucket-restore
  })

  (mkIf cfg.enable {
    ns.services.failureNotifyServices = mkIf cfg.runMaintenance {
      restic-repo-maintenance = failureCfg;
    };

    systemd.services = mkMerge (
      [
        (mapAttrs' (
          name: backup:
          nameValuePair "restic-backups-${name}" {
            enable = mkIf cfg.server.enable (!inputs.firstBoot.value);
            after = optional cfg.server.enable "caddy.service";
            requires = optional cfg.server.enable "caddy.service";

            environment = {
              RESTIC_CACHE_DIR = cacheDir;
              RESTIC_PASSWORD_FILE = resticPasswordFile.path;
              RESTIC_REPOSITORY_FILE = resticRepositoryFile.path;
            };

            preStart = ''
              ${resticExe} cat config --no-lock >/dev/null || ${resticExe} init
            '';

            serviceConfig = {
              Type = "oneshot";

              ExecStart =
                let
                  excludeFlag =
                    optional (backup.backendOptions.exclude != [ ])
                      "--exclude-file=${pkgs.writeText "restic-backup-${name}-exclude-patterns" (concatStringsSep "\n" backup.backendOptions.exclude)}";
                in
                utils.escapeSystemdExecArgs (
                  [
                    resticExe
                    "backup"
                  ]
                  ++ backup.backendOptions.extraBackupArgs
                  ++ excludeFlag
                  ++ backup.paths
                );

              # There is no point in restarting Restic backups as we would only ever want to
              # restart after network errors and restic has a built-in incremental retry
              # mechanism that cannot currently be disabled
              # https://github.com/restic/restic/issues/5463
              Restart = mkForce "no";

              # we intentially do NOT set CacheDirectory because it's shared between units
              PrivateTmp = true;
            };
          }
        ) backups)
      ]
      ++ optionals cfg.runMaintenance [
        {
          # Rather than pruning and checking integrity with every backup service
          # we run a single maintenance service after all backups have completed
          "restic-repo-maintenance" = {
            restartIfChanged = false;
            after =
              optional (!cfg.server.enable) "network-online.target"
              ++ optional cfg.server.enable "caddy.service"
              ++ map (backup: "restic-backups-${backup}.service") (attrNames backups);
            wants = optional (!cfg.server.enable) "network-online.target";
            requires = optional cfg.server.enable "caddy.service";

            environment = {
              RESTIC_CACHE_DIR = cacheDir;
              RESTIC_REPOSITORY_FILE = resticRepositoryFile.path;
              RESTIC_PASSWORD_FILE = resticPasswordFile.path;
            };

            serviceConfig = {
              Type = "oneshot";
              ExecStart = [
                "${resticExe} unlock" # we can safely unlock https://github.com/NixOS/nixpkgs/pull/387116/changes/138abab480251e74ab0214a867f365b1be69f814
                "${resticExe} forget --cleanup-cache --retry-lock 5m --prune ${concatStringsSep " " pruneOpts}"
                "${resticExe} check --with-cache --read-data-subset=500M --retry-lock 5m"
              ];
              PrivateTmp = true;
              Restart = "no";
            };
          };
        }
      ]
    );

    systemd.timers = mkMerge [
      (mapAttrs' (
        name: _:
        nameValuePair "restic-backups-${name}" {
          inherit (cfg) timerConfig;
          enable = mkIf cfg.server.enable (!inputs.firstBoot.value);
          wantedBy = [ "timers.target" ];
          unitConfig.X-OnlyManualStart = true;
        }
      ) backups)

      (mkIf cfg.runMaintenance {
        restic-repo-maintenance = {
          inherit (cfg) timerConfig;
          enable = !inputs.firstBoot.value;
          wantedBy = [ "timers.target" ];
          unitConfig.X-OnlyManualStart = true;
        };
      })
    ];
  })

  (mkIf (cfg.server.enable && !virtualisation.vmVariant && !inputs.vmInstall.value) {
    requirements = [ "services.caddy" ];

    asserts = [
      (config.${ns}.core.device.type == "server")
      "Restic server can only be enabled on server hosts"
    ];

    # Use `htpasswd -B -c .htpasswd username` to generate login credentials for hosts

    ns.services.failureNotifyServices = {
      restic-remote-copy = failureCfg;
      restic-remote-maintenance = failureCfg;
    };

    services."restic".server = {
      enable = true;
      dataDir = cfg.server.dataDir;
      # WARN: If the port is changed the restic-rest-server.socket unit has to
      # be manually restarted
      listenAddress = toString cfg.server.port;
      extraFlags = [
        "--htpasswd-file"
        "${resticHtPasswordsFile.path}"
      ];
    };

    ns.services.healthCheckServices."restic-remote-copy" = { };

    systemd.services = mkMerge [
      {
        "restic-remote-copy" = {
          enable = !inputs.firstBoot.value;
          wants = [ "network-online.target" ];
          requires = [ "caddy.service" ];
          after = [
            "network-online.target"
            "caddy.service"
          ]
          ++ optional cfg.runMaintenance "restic-repo-maintenance.service";
          restartIfChanged = false;

          environment = {
            RESTIC_CACHE_DIR = cacheDir;
            RESTIC_FROM_REPOSITORY_FILE = resticRepositoryFile.path;
            RESTIC_FROM_PASSWORD_FILE = resticPasswordFile.path;
            RESTIC_PASSWORD_FILE = resticPasswordFile.path;
          };

          preStart = ''
            # Initialise with copied chunker params to ensure good deduplication
            ${resticExe} cat config --no-lock >/dev/null || ${resticExe} init --copy-chunker-params
          '';

          serviceConfig = {
            Type = "oneshot";
            EnvironmentFile = resticReadWriteBackblazeVars.path;
            ExecStart = [
              "${resticExe} copy --retry-lock 5m"
              "${resticExe} check --with-cache --retry-lock 5m"
            ];
            PrivateTmp = true;
            Restart = "no";
          };
        };

        "restic-remote-maintenance" = {
          enable = !inputs.firstBoot.value;
          wants = [ "network-online.target" ];
          requires = [ "caddy.service" ];
          after = [
            "network-online.target"
            "restic-remote-copy.service"
            "caddy.service"
          ];
          restartIfChanged = false;

          environment = {
            RESTIC_CACHE_DIR = cacheDir;
            RESTIC_FROM_REPOSITORY_FILE = resticRepositoryFile.path;
            RESTIC_FROM_PASSWORD_FILE = resticPasswordFile.path;
            RESTIC_PASSWORD_FILE = resticPasswordFile.path;
          };

          serviceConfig = {
            Type = "oneshot";
            EnvironmentFile = resticReadWriteBackblazeVars.path;
            ExecStart = [
              "${resticExe} unlock" # we can safely unlock https://github.com/NixOS/nixpkgs/pull/387116/changes/138abab480251e74ab0214a867f365b1be69f814
              "${resticExe} forget --cleanup-cache --retry-lock 5m --prune ${concatStringsSep " " pruneOpts}"
              # In practice bandwidth usage seems to be data-subset * 2
              "${resticExe} check --with-cache --read-data-subset=400M --retry-lock 5m"
            ];
            PrivateTmp = true;
            Restart = "no";
          };
        };
      }
    ];

    systemd.timers = {
      "restic-remote-copy" = {
        # Do not enable on firstBoot of a brand new deployment because we want to
        # manually copy the remote repo first
        enable = !inputs.firstBoot.value;
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = cfg.server.remoteCopySchedule;
          Persistent = true;
        };
      };

      "restic-remote-maintenance" = {
        enable = !inputs.firstBoot.value;
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = cfg.server.remoteMaintenanceSchedule;
          Persistent = true;
        };
      };
    };

    ns.services.caddy.virtualHosts.restic.extraConfig = ''
      # Because syncing involves many HTTP requests logs get very large.
      # Exclude LAN IPs from logs to circumvent this.
      @lan remote_ip ${concatStringsSep " " trustedAddresses}
      log_skip @lan
      reverse_proxy http://127.0.0.1:${toString cfg.server.port}
    '';

    ns.persistence.directories = [
      {
        directory = cfg.server.dataDir;
        user = "restic";
        group = "restic";
        mode = "0700";
      }
    ];
  })
]
