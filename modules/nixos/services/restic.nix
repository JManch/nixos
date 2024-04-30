{ lib
, pkgs
, config
, inputs
, outputs
, hostname
, username
, ...
} @ args:
let
  inherit (lib)
    mkIf
    mkMerge
    utils
    all
    elem
    mapAttrs
    getExe
    concatStrings
    concatStringsSep
    nameValuePair
    mapAttrs'
    getExe'
    attrNames
    attrValues
    mkForce
    mkBefore
    optionalString;
  inherit (config.modules.services) caddy;
  inherit (inputs.nix-resources.secrets) fqDomain;
  inherit (config.modules.system.virtualisation) vmVariant;
  inherit (config.age.secrets)
    resticPasswordFile
    resticHtPasswordsFile
    resticRepositoryFile
    resticReadWriteBackblazeVars
    resticReadOnlyBackblazeVars
    resticNotifVars
    healthCheckResticRemoteCopy;
  cfg = config.modules.services.restic;
  isServer = (config.device.type == "server");
  restic = getExe pkgs.restic;
  homeBackups = (utils.homeConfig args).backups;

  # WARN: Paths are prefixed with /persist. We don't modify exclude or include
  # paths to allow non-absolute patterns. Be careful with those.
  backups = mapAttrs
    (name: value:
      value // {
        paths = map (path: "/persist${path}") value.paths;
        restore = value.restore // {
          pathOwnership = mapAttrs'
            (path: value: nameValuePair "/persist${path}" value)
            value.restore.pathOwnership;
        };
      }
    )
    (cfg.backups // homeBackups);

  backupTimerConfig = {
    OnCalendar = if isServer then "*-*-* 00:00:00" else "*-*-* 15:00:00";
    Persistent = !isServer;
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
        EnvironmentFile = resticNotifVars.path;
        ExecStart =
          let
            shoutrrr = getExe outputs.packages.${pkgs.system}.shoutrrr;
          in
          pkgs.writeShellScript "${name}" ''
            ${shoutrrr} send \
              --url "discord://$DISCORD_AUTH" \
              --title "${title}" \
              --message "${message} failed on host ${hostname}"

            ${shoutrrr} send \
              --url "smtp://$SMTP_USERNAME:$SMTP_PASSWORD@$SMTP_HOST:$SMTP_PORT/?from=$SMTP_FROM&to=JManch@protonmail.com&Subject=${lib.replaceStrings [ " " ] [ "%20" ] title}" \
              --message "${name} failed on ${hostname}"
          '';
      };
    };
  };

  restoreScript = pkgs.writeShellApplication {
    name = "restic-restore";
    runtimeInputs = [ pkgs.restic pkgs.coreutils ];
    text = /*bash*/ ''

      echo "Leave empty to restore from the default repo"
      echo "Enter 'remote' to restore from the backblaze remote repo"
      echo "Otherwise, enter a custom repo passed to the -r flag"
      read -p "Enter the repo to restore from: " -r repo

      env_vars="RESTIC_PASSWORD_FILE=\"${resticPasswordFile.path}\""
      if [[ -z "$repo" ]]; then
        env_vars+=" RESTIC_REPOSITORY_FILE=\"${resticRepositoryFile.path}\""
      elif [[ ! "remote" = "$repo" ]]; then
        env_vars+=" RESTIC_REPOSITORY=\"$repo\""
      fi

      load_vars="set -a; if [[ \"$repo\" = \"remote\" ]]; then source ${resticReadOnlyBackblazeVars.path}; fi; set +a; export $env_vars;"
      sudo ${getExe' pkgs.bash "sh"} -c "$load_vars restic snapshots --compact --no-lock --group-by tags"

      read -p "Do you want to proceed with this repo? (y/N): " -n 1 -r
      if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then exit 1; fi
      echo

      ${concatStrings (attrValues (mapAttrs (name: value: /*bash*/ ''
        read -p "Restore backup ${name}? (y/N): " -n 1 -r
        if [[ "$REPLY" =~ ^[Yy]$ ]]; then
            echo
            sudo ${getExe' pkgs.bash "sh"} -c "$load_vars restic snapshots --tag ${name} --host ${hostname} --no-lock"
            read -p "Enter the snapshot ID to restore (leave empty for latest): " -r snapshot
            if [[ -z "$snapshot" ]]; then snapshot="latest"; fi
            echo "Restoring snapshot: $snapshot"

            ${optionalString value.restore.removeExisting (
              concatStringsSep ";" (map (path: "sudo rm -rf ${path}/*") value.paths)
            )}

            ${value.restore.preRestoreScript}
            sudo ${getExe' pkgs.bash "sh"} -c "$load_vars restic restore $snapshot --target / --verify --tag ${name} --host ${hostname} --no-lock"

            # Update ownership because UID/GID mappings are not guaranteed to match between hosts
            # Modules with statically mapped IDs don't need this https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/misc/ids.nix
            ${concatStringsSep ";" (attrValues (mapAttrs (path: ownership:
              (optionalString (ownership.user != null) "sudo chown -R ${ownership.user} ${path}") +
              (optionalString (ownership.group != null) ";sudo chgrp -R ${ownership.group} ${path}")
              ) value.restore.pathOwnership))}

            ${value.restore.postRestoreScript}
        fi
      '') backups))}

    '';
  };
in
mkMerge [
  # To allow testing backup restores in the VM
  (mkIf (cfg.enable || cfg.server.enable || vmVariant) {
    assertions =
      utils.asserts [
        (all (v: v == true) (attrValues (mapAttrs (_: backup: all (v: v == true) (map (path: elem path backup.paths) (attrNames backup.restore.pathOwnership))) backups)))
        "Restic pathOwnership paths must also be defined as backup paths"
        (all (v: v == true) (attrValues (mapAttrs (_: backup: all (v: v == true) (map (path: path != "") backup.paths)) cfg.backups)))
        "Restic backup paths cannot be empty"
        (all (v: v == true) (attrValues (mapAttrs (_: backup: all (v: v == true) (map (path: path != "/home/${username}/") backup.paths)) homeBackups)))
        "Restic home backup paths cannot be empty"
      ];

    environment.systemPackages = [ pkgs.restic restoreScript ];

    # NOTE: Always interact with the repository using the REST server, even on
    # the same machine. It ensures correct repo file ownership.
    programs.zsh.shellAliases = {
      restic = "sudo restic --repository-file ${resticRepositoryFile.path} --password-file ${resticPasswordFile.path}";
      restic-snapshots = "sudo restic snapshots --compact --group-by tags --repository-file ${resticRepositoryFile.path} --password-file ${resticPasswordFile.path}";
      restic-restore-size = "sudo restic stats --repository-file ${resticRepositoryFile.path} --password-file ${resticPasswordFile.path}";
      restic-repo-size = "sudo restic stats --mode raw-data --repository-file ${resticRepositoryFile.path} --password-file ${resticPasswordFile.path}";
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
    # with Restic. This gives me 7 days after a theoretical attack to use
    # restore an old 'snapshot' of the bucket.

    # Restore tool: https://github.com/viltgroup/bucket-restore
  })

  (mkIf cfg.enable {
    services.restic.backups =
      let
        backupDefaults = name: {
          # We use our own initialize script because the upstream one is inefficient
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
      mapAttrs
        (name: value: (backupDefaults name) // (removeAttrs value [ "restore" ]))
        backups;

    systemd.services =
      (mapAttrs'
        (name: value: nameValuePair "restic-backups-${name}" {
          enable = mkIf cfg.server.enable (!inputs.firstBoot.value);
          environment.RESTIC_CACHE_DIR = mkForce "";
          serviceConfig.EnvironmentFile = resticNotifVars.path;
          serviceConfig.CacheDirectory = mkForce "";
          onFailure = [ "restic-backups-${name}-failure-notif.service" ];
          preStart = mkBefore /*bash*/ ''
            ${restic} --no-cache cat config || ${restic} init
          '';
        })
        backups)
      //
      (mapAttrs'
        (name: value:
          let
            failureServiceName = "restic-backups-${name}-failure-notif";
            service = failureNotifService failureServiceName
              "Restic Backup ${name} Failed"
              "${name} backup";
          in
          nameValuePair failureServiceName service.${failureServiceName}
        )
        backups)
      //
      {
        # Rather than pruning and checking integrity with every backup service
        # we run a single maintenance service after all backups have completed
        restic-repo-maintenance = {
          restartIfChanged = false;
          after = map (backup: "restic-backups-${backup}.service") (attrNames backups);
          onFailure = [ "restic-repo-maintenance-failure-notif.service" ];

          environment = {
            RESTIC_REPOSITORY_FILE = resticRepositoryFile.path;
            RESTIC_PASSWORD_FILE = resticPasswordFile.path;
          };

          serviceConfig = {
            Type = "oneshot";
            PrivateTmp = true;
            ExecStart = [
              "${restic} forget --no-cache --prune ${concatStringsSep " " pruneOpts}"
              # Retry lock timeout in-case another host is performing a check
              "${restic} check --read-data-subset=500M --retry-lock 5m"
            ];
          };
        };
      }
      // (
        failureNotifService "restic-repo-maintenance-failure-notif"
          "Restic Repo Maintenance Failed"
          "Repo maintenance"
      );

    systemd.timers.restic-repo-maintenance = {
      enable = !inputs.firstBoot.value;
      wantedBy = [ "timers.target" ];
      timerConfig = backupTimerConfig;
    };
  })

  (mkIf cfg.server.enable {
    assertions = utils.asserts [
      caddy.enable
      "Restic server requires Caddy to be enabled"
      isServer
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

    systemd.services = {
      restic-remote-copy = {
        enable = !inputs.firstBoot.value;
        wants = [ "network-online.target" ];
        after = [ "network-online.target" ];
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
          ${restic} cat config || ${restic} init --copy-chunker-params
        '';

        serviceConfig = {
          Type = "oneshot";
          EnvironmentFile = resticReadWriteBackblazeVars.path;
          ExecStart = [
            "${restic} copy"
            "${restic} check --with-cache"
          ];
          ExecStartPost = "${getExe' pkgs.bash "sh"} -c '${getExe pkgs.curl} -s \"$(<${healthCheckResticRemoteCopy.path})\"'";

          User = "root";
          PrivateTmp = true;
          RuntimeDirectory = "restic-remote-copy";
          CacheDirectory = "restic-remote-copy";
          CacheDirectoryMode = "0700";
        };
      };

      restic-remote-maintenance = {
        enable = !inputs.firstBoot.value;
        wants = [ "network-online.target" ];
        after = [ "network-online.target" ];
        onFailure = [ "restic-remote-maintenance-failure-notif.service" ];
        restartIfChanged = false;

        environment = {
          RESTIC_FROM_REPOSITORY_FILE = resticRepositoryFile.path;
          RESTIC_FROM_PASSWORD_FILE = resticPasswordFile.path;
          RESTIC_PASSWORD_FILE = resticPasswordFile.path;
        };

        preStart = ''
          # Ensure the repository exists
          ${restic} cat config
        '';

        serviceConfig = {
          Type = "oneshot";
          EnvironmentFile = resticReadWriteBackblazeVars.path;

          ExecStart = [
            "${restic} forget --prune ${concatStringsSep " " pruneOpts}"
            # WARN: Keep an eye on this with egress fees
            "${restic} check --read-data-subset=500M"
          ];

          User = "root";
          PrivateTmp = true;
          RuntimeDirectory = "restic-remote-maintenance";
        };
      };
    } // (failureNotifService "restic-remote-copy-failure-notif"
      "Restic Remote Copy Failed"
      "Remote copy"
    ) // (failureNotifService "restic-remote-maintenance-failure-notif"
      "Restic Remote Maintenance Failed"
      "Remote maintenance"
    );

    systemd.timers = {
      restic-remote-copy = {
        # Do not enable on firstBoot of a brand new deployment because we want to
        # manually copy the remote repo first
        enable = !inputs.firstBoot.value;
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "*-*-* 01:00:00";
          Persistent = false;
        };
      };

      restic-remote-maintenance = {
        enable = !inputs.firstBoot.value;
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "Sun *-*-* 01:30:00";
          Persistent = true;
        };
      };
    };

    services.caddy.virtualHosts = {
      "restic.${fqDomain}".extraConfig = ''
        import lan_only
        reverse_proxy http://127.0.0.1:${toString cfg.server.port}
      '';
    };

    persistence.directories = [
      {
        directory = cfg.server.dataDir;
        user = "restic";
        group = "restic";
        mode = "700";
      }
      {
        # Persist cache because we want to avoid read operations from B2 storage
        directory = "/var/cache/restic-remote-copy";
        user = "root";
        group = "root";
        mode = "700";
      }
    ];
  })
]
