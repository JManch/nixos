{
  lib,
  cfg,
  pkgs,
  self,
  config,
  inputs,
  hostname,
  username,
}:
let
  inherit (lib)
    ns
    mkIf
    mkMerge
    all
    elem
    hasPrefix
    mapAttrs
    mapAttrsToList
    getExe
    replaceStrings
    concatStrings
    concatStringsSep
    concatMapStrings
    concatMapStringsSep
    nameValuePair
    optionalAttrs
    optionals
    optional
    mapAttrs'
    getExe'
    attrNames
    mkForce
    mkBefore
    mkAfter
    optionalString
    singleton
    mkOption
    mkEnableOption
    mkAliasOptionModule
    types
    ;
  inherit (lib.${ns}) upperFirstChar;
  inherit (config.${ns}.services) caddy;
  inherit (config.${ns}.core) home-manager;
  inherit (config.${ns}.system) impermanence virtualisation;
  inherit (caddy) trustedAddresses;
  inherit (cfg) backups;
  inherit (config.age.secrets)
    resticPasswordFile
    resticHtPasswordsFile
    resticRepositoryFile
    resticReadWriteBackblazeVars
    resticReadOnlyBackblazeVars
    notifVars
    healthCheckResticRemoteCopy
    ;
  resticExe = getExe pkgs.restic;
  homeBackups = optionalAttrs home-manager.enable config.${ns}.hmNs.backups;
  vmInstall = inputs.vmInstall.value;

  backupTimerConfig = {
    OnCalendar = cfg.backupSchedule;
    Persistent = true;
  };

  pruneOpts = [
    "--keep-daily 7"
    "--keep-weekly 4"
    "--keep-monthly 6"
    "--keep-yearly 3"
  ];

  failureNotifService = name: title: message: {
    ${name} = {
      restartIfChanged = false;
      serviceConfig = {
        Type = "oneshot";
        EnvironmentFile = notifVars.path;
        ExecStart =
          let
            shoutrrr = getExe pkgs.shoutrrr;
          in
          pkgs.writeShellScript "${name}" ''
            ${shoutrrr} send \
              --url "discord://$RESTIC_DISCORD_AUTH" \
              --title "${title}" \
              --message "${message} failed on host ${hostname}"

            ${shoutrrr} send \
              --url "smtp://$SMTP_USERNAME:$SMTP_PASSWORD@$SMTP_HOST:$SMTP_PORT/?from=$SMTP_FROM&to=JManch@protonmail.com&Subject=${
                replaceStrings [ " " ] [ "%20" ] title
              }" \
              --message "${name} failed on ${hostname}"
          '';
      };
    };
  };

  restoreScript = pkgs.writeShellApplication {
    name = "restic-restore";
    runtimeInputs = with pkgs; [
      restic
      coreutils
      systemd
      bash
    ];
    text = # bash
      ''
        echo "Leave empty to restore from the default repo"
        echo "Enter 'remote' to restore from the backblaze remote repo"
        echo "Otherwise, enter a custom repo passed to the -r flag"
        read -p "Enter the repo to restore from: " -r repo

        env_vars="RESTIC_PASSWORD_FILE=\"${resticPasswordFile.path}\""
        if [ -z "$repo" ]; then
          env_vars+=" RESTIC_REPOSITORY_FILE=\"${resticRepositoryFile.path}\""
        elif [ ! "remote" = "$repo" ]; then
          env_vars+=" RESTIC_REPOSITORY=\"$repo\""
        fi

        load_vars="set -a; if [[ \"$repo\" = \"remote\" ]]; then source ${resticReadOnlyBackblazeVars.path}; fi; set +a; export $env_vars;"
        sudo sh -c "$load_vars restic snapshots --compact --no-lock --group-by tags"

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
                  sudo sh -c "$load_vars restic snapshots --tag ${name} --host ${hostname} --no-lock"
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
                    sudo sh -c "$load_vars restic restore $snapshot --target $target --verify --tag ${name} --host ${hostname} --no-lock"
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
              '') self.nixosConfigurations.${hostname}.config.${ns}.services.restic.backups
          )
        ) (attrNames self.nixosConfigurations)}
      '';
  };
in
[
  {
    guardType = "custom";

    imports = singleton (
      mkAliasOptionModule
        [ ns "backups" ]
        [
          ns
          "services"
          "restic"
          "backups"
        ]
    );

    opts = {
      runMaintenance = mkEnableOption "repo maintenance after performing backups" // {
        default = true;
      };

      backups = mkOption {
        type = types.attrsOf (
          types.submodule {
            freeformType = types.attrsOf types.anything;
            options = {
              preBackupScript = mkOption {
                type = types.lines;
                default = "";
                description = "Script to run before backing up";
              };

              postBackupScript = mkOption {
                type = types.lines;
                default = "";
                description = "Script to run after backing up";
              };

              restore = {
                pathOwnership = mkOption {
                  type = types.attrsOf (
                    types.submodule {
                      options = {
                        user = mkOption {
                          type = types.nullOr types.str;
                          default = null;
                          description = ''
                            User to set restored files to. If null, user will not
                            be changed. Useful for modules that do not have static
                            IDs https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/misc/ids.nix.
                          '';
                        };

                        group = mkOption {
                          type = types.nullOr types.str;
                          default = null;
                          description = ''
                            Group to set restored files to. If null, group will not
                            be changed.
                          '';
                        };
                      };
                    }
                  );
                  default = { };
                  description = ''
                    Attribute for assigning ownership user and group for each
                    backup path.
                  '';
                };

                removeExisting = mkOption {
                  type = types.bool;
                  default = true;
                  description = ''
                    Whether to delete all files and directories in the backup
                    paths before restoring backup.
                  '';
                };

                preRestoreScript = mkOption {
                  type = types.lines;
                  default = "";
                  description = "Script to run before restoring the backup";
                };

                postRestoreScript = mkOption {
                  type = types.lines;
                  default = "";
                  description = "Script to run after restoring the backup";
                };
              };

            };
          }
        );
        default = { };
        apply =
          # Modify the backup paths and ownership paths to include persistence
          # path if impermanence is enabled and merge with home manager backups

          # WARN: Exclude and include paths are not prefixed with persistence
          # to allow non-absolute patterns, be careful with those
          backups:
          mapAttrs (
            name: value:
            value
            // {
              paths = map (path: "${optionalString impermanence.enable "/persist"}${path}") value.paths;
              restore = value.restore // {
                pathOwnership = mapAttrs' (
                  path: value: nameValuePair "${optionalString impermanence.enable "/persist"}${path}" value
                ) value.restore.pathOwnership;
              };
            }
          ) (backups // homeBackups);
        description = ''
          Attribute set of Restic backups matching the upstream module backups
          options.
        '';
      };

      backupSchedule = mkOption {
        type = types.str;
        default = "*-*-* 05:30:00";
        description = "Backup service default OnCalendar schedule";
      };

      server = {
        enable = mkEnableOption "Restic REST server";

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

  # To allow testing backup restores in the VM
  (mkIf (cfg.enable || cfg.server.enable || (cfg.enable && virtualisation.vmVariant)) {
    ns.adminPackages = [
      pkgs.restic
      restoreScript
    ];

    # WARN: Always interact with the repository using the REST server, even on
    # the same machine. It ensures correct repo file ownership.
    programs.zsh.shellAliases =
      let
        systemctl = getExe' pkgs.systemd "systemctl";
      in
      {
        restic = "sudo restic --no-cache --repository-file ${resticRepositoryFile.path} --password-file ${resticPasswordFile.path}";
        restic-snapshots = "sudo restic snapshots --no-cache --compact --group-by tags --repository-file ${resticRepositoryFile.path} --password-file ${resticPasswordFile.path}";
        restic-restore-size = "sudo restic stats --no-cache --repository-file ${resticRepositoryFile.path} --password-file ${resticPasswordFile.path}";
        restic-repo-size = "sudo restic stats --no-cache --mode raw-data --repository-file ${resticRepositoryFile.path} --password-file ${resticPasswordFile.path}";
        backup-all = concatStringsSep ";" (
          mapAttrsToList (name: _: "sudo ${systemctl} start restic-backups-${name}") backups
        );
      }
      // (mapAttrs' (
        name: _: nameValuePair "backup-${name}" "sudo ${systemctl} start restic-backups-${name}"
      ) backups);

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

  (mkIf (cfg.enable && !virtualisation.vmVariant && !vmInstall) {
    asserts = [
      (all (v: v == true) (
        mapAttrsToList (
          _: backup:
          all (v: v == true) (
            map (path: (elem path backup.paths) || (all (p: hasPrefix path p) backup.paths)) (
              attrNames backup.restore.pathOwnership
            )
          )
        ) backups
      ))
      "Restic pathOwnership paths must be a part of the backup paths"
      (all (v: v == true) (
        mapAttrsToList (_: backup: all (v: v == true) (map (path: path != "") backup.paths)) cfg.backups
      ))
      "Restic backup paths cannot be empty"
      (all (v: v == true) (
        mapAttrsToList (
          _: backup: all (v: v == true) (map (path: path != "/home/${username}/") backup.paths)
        ) homeBackups
      ))
      "Restic home backup paths cannot be empty"
    ];

    services.restic.backups =
      let
        backupDefaults = name: {
          # We use our own initialization script because upstream uses `restic
          # cat` without `--no-lock`
          initialize = false;
          repositoryFile = resticRepositoryFile.path;
          passwordFile = resticPasswordFile.path;
          timerConfig = backupTimerConfig;
          extraBackupArgs = [
            # Disable cache because we don't persist cache directories
            "--no-cache"
            "--no-scan"
            "--tag ${name}"
          ];
        };
      in
      mapAttrs (
        name: value:
        (backupDefaults name)
        // (removeAttrs value [
          "restore"
          "preBackupScript"
          "postBackupScript"
        ])
      ) backups;

    systemd.services = mkMerge (
      [
        (mapAttrs' (
          name: value:
          nameValuePair "restic-backups-${name}" {
            enable = mkIf cfg.server.enable (!inputs.firstBoot.value);
            after = optional cfg.server.enable "caddy.service";
            requires = optional cfg.server.enable "caddy.service";
            environment.RESTIC_CACHE_DIR = mkForce "";
            onFailure = [ "restic-backups-${name}-failure-notif.service" ];

            preStart = mkBefore ''
              ${value.preBackupScript}
              ${resticExe} cat config --no-cache --no-lock > /dev/null || ${resticExe} init
            '';

            postStop = mkAfter ''
              ${value.postBackupScript}
            '';

            serviceConfig.CacheDirectory = mkForce "";
          }
        ) backups)
        (mapAttrs' (
          name: value:
          let
            failureServiceName = "restic-backups-${name}-failure-notif";
            capitalisedNamed = upperFirstChar name;
            service =
              failureNotifService failureServiceName "Restic Backup ${capitalisedNamed} Failed"
                "${capitalisedNamed} backup";
          in
          nameValuePair failureServiceName service.${failureServiceName}
        ) backups)
      ]
      ++ optionals cfg.runMaintenance [
        {
          # Rather than pruning and checking integrity with every backup service
          # we run a single maintenance service after all backups have completed
          restic-repo-maintenance = {
            restartIfChanged = false;
            after = map (backup: "restic-backups-${backup}.service") (attrNames backups);
            requires = optional cfg.server.enable "caddy.service";
            onFailure = [ "restic-repo-maintenance-failure-notif.service" ];

            environment = {
              RESTIC_CACHE_DIR = "/var/cache/restic-repo-maintenance";
              RESTIC_REPOSITORY_FILE = resticRepositoryFile.path;
              RESTIC_PASSWORD_FILE = resticPasswordFile.path;
            };

            serviceConfig = {
              Type = "oneshot";
              ExecStart = [
                "${resticExe} forget --prune ${concatStringsSep " " pruneOpts} --retry-lock 5m"
                # Retry lock timeout in-case another host is performing a check
                "${resticExe} check --read-data-subset=500M --retry-lock 5m"
              ];

              PrivateTmp = true;
              RuntimeDirectory = "restic-repo-maintenance";
              CacheDirectory = "restic-repo-maintenance";
              CacheDirectoryMode = "0700";
            };
          };
        }
        (failureNotifService "restic-repo-maintenance-failure-notif" "Restic Repo Maintenance Failed"
          "Repo maintenance"
        )
      ]
    );

    systemd.timers.restic-repo-maintenance = {
      enable = !inputs.firstBoot.value;
      wantedBy = [ "timers.target" ];
      timerConfig = backupTimerConfig;
    };

    # Persist maintenance service cache otherwise forget command can be very
    # expensive
    ns.persistence.directories = singleton {
      directory = "/var/cache/restic-repo-maintenance";
      mode = "0700";
    };
  })

  (mkIf (cfg.server.enable && !virtualisation.vmVariant && !vmInstall) {
    requirements = [ "services.caddy" ];

    asserts = [
      (config.${ns}.core.device.type == "server")
      "Restic server can only be enabled on server hosts"
    ];

    # Use `htpasswd -B -c .htpasswd username` to generate login credentials for hosts

    services.restic.server = {
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

    systemd.services = mkMerge [
      {
        restic-remote-copy = {
          enable = !inputs.firstBoot.value;
          wants = [ "network-online.target" ];
          requires = [ "caddy.service" ];
          after = [
            "network-online.target"
            "restic-repo-maintenance.service"
            "caddy.service"
          ];
          onFailure = [ "restic-remote-copy-failure-notif.service" ];
          restartIfChanged = false;

          environment = {
            RESTIC_CACHE_DIR = "/var/cache/restic-remote-copy";
            RESTIC_FROM_REPOSITORY_FILE = resticRepositoryFile.path;
            RESTIC_FROM_PASSWORD_FILE = resticPasswordFile.path;
            RESTIC_PASSWORD_FILE = resticPasswordFile.path;
          };

          preStart = ''
            # Initialise with copied chunker params to ensure good deduplication
            ${resticExe} cat config || ${resticExe} init --copy-chunker-params
          '';

          serviceConfig = {
            Type = "oneshot";
            EnvironmentFile = resticReadWriteBackblazeVars.path;
            ExecStart = [
              "${resticExe} copy"
              "${resticExe} check --with-cache --retry-lock 5m"
            ];
            ExecStartPost = "${getExe' pkgs.bash "sh"} -c '${getExe pkgs.curl} -s \"$(<${healthCheckResticRemoteCopy.path})\"'";

            PrivateTmp = true;
            RuntimeDirectory = "restic-remote-copy";
            CacheDirectory = "restic-remote-copy";
            CacheDirectoryMode = "0700";
          };
        };

        restic-remote-maintenance = {
          enable = !inputs.firstBoot.value;
          wants = [ "network-online.target" ];
          requires = [ "caddy.service" ];
          after = [
            "network-online.target"
            "restic-remote-copy.service"
            "caddy.service"
          ];
          onFailure = [ "restic-remote-maintenance-failure-notif.service" ];
          restartIfChanged = false;

          environment = {
            RESTIC_CACHE_DIR = "/var/cache/restic-remote-maintenance";
            RESTIC_FROM_REPOSITORY_FILE = resticRepositoryFile.path;
            RESTIC_FROM_PASSWORD_FILE = resticPasswordFile.path;
            RESTIC_PASSWORD_FILE = resticPasswordFile.path;
          };

          preStart = ''
            # Ensure the repository exists
            ${resticExe} cat config
          '';

          serviceConfig = {
            Type = "oneshot";
            EnvironmentFile = resticReadWriteBackblazeVars.path;
            ExecStart = [
              "${resticExe} forget --prune ${concatStringsSep " " pruneOpts} --retry-lock 5m"
              # In practice bandwidth usage seems to be data-subset * 2
              "${resticExe} check --read-data-subset=400M --retry-lock 5m"
            ];

            PrivateTmp = true;
            RuntimeDirectory = "restic-remote-maintenance";
            CacheDirectory = "restic-remote-maintenance";
            CacheDirectoryMode = "0700";
          };
        };
      }
      (failureNotifService "restic-remote-copy-failure-notif" "Restic Remote Copy Failed" "Remote copy")
      (failureNotifService "restic-remote-maintenance-failure-notif" "Restic Remote Maintenance Failed"
        "Remote maintenance"
      )
    ];

    systemd.timers = {
      restic-remote-copy = {
        # Do not enable on firstBoot of a brand new deployment because we want to
        # manually copy the remote repo first
        enable = !inputs.firstBoot.value;
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = cfg.server.remoteCopySchedule;
          Persistent = true;
        };
      };

      restic-remote-maintenance = {
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
      # Persist cache because we want to avoid read operations from B2 storage
      {
        directory = "/var/cache/restic-remote-copy";
        mode = "0700";
      }
      {
        directory = "/var/cache/restic-remote-maintenance";
        mode = "0700";
      }
    ];
  })
]
