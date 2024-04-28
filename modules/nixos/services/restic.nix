{ lib
, pkgs
, config
, inputs
, outputs
, ...
} @ args:
let
  inherit (lib) mkIf mkMerge utils mapAttrs getExe concatStringsSep nameValuePair mapAttrs' getExe';
  inherit (config.modules.services) caddy;
  inherit (inputs.nix-resources.secrets) fqDomain;
  inherit (config.age.secrets)
    resticPasswordFile
    resticHtPasswordsFile
    resticRepositoryFile
    resticBackblazeVars
    resticNotifVars
    healthCheckResticRemoteCopy;
  cfg = config.modules.services.restic;
  backups = cfg.backups // (utils.homeConfig args).backups;
  isServer = (config.device.type == "server");

  pruneOpts = [
    "--keep-daily 7"
    "--keep-weekly 4"
    "--keep-monthly 6"
    "--keep-yearly 3"
  ];
in
mkMerge [
  (mkIf (cfg.enable || cfg.server.enable) {
    environment.systemPackages = [ pkgs.restic ];
  })

  (mkIf cfg.enable {
    services.restic.backups =
      let
        backupDefaults = {
          inherit pruneOpts;
          initialize = true;
          # NOTE: Always perform backups using the REST server, even on the same
          # machine. It simplifies permission handling.
          repositoryFile = resticRepositoryFile.path;
          passwordFile = resticPasswordFile.path;

          timerConfig = {
            OnCalendar = if isServer then "*-*-* 00:00:00" else "*-*-* 15:00:00";
            Persistent = !isServer;
          };
        };
      in
      mapAttrs
        (_: value: backupDefaults // value)
        backups;

    systemd.services = (mapAttrs'
      (name: value: nameValuePair "restic-backups-${name}" {
        enable = mkIf cfg.server.enable (!inputs.firstBoot.value);
        serviceConfig.EnvironmentFile = resticNotifVars.path;
        onFailure = [ "restic-backups-${name}-failure-notif.service" ];
      })
      backups) // (mapAttrs'
      (name: value: nameValuePair "restic-backups-${name}-failure-notif" {
        restartIfChanged = false;
        serviceConfig = {
          Type = "oneshot";
          EnvironmentFile = resticNotifVars.path;
          ExecStart =
            let
              shoutrrr = getExe outputs.packages.${pkgs.system}.shoutrrr;
            in
            pkgs.writeShellScript "restic-${name}-notif" ''
              ${shoutrrr} send \
                --url "discord://$DISCORD_AUTH" \
                --title "Restic '${name}' Backup Failed" \
                --message "${name} backup failed"

              ${shoutrrr} send \
                --url "smtp://$SMTP_USERNAME:$SMTP_PASSWORD@$SMTP_HOST:$SMTP_PORT/?from=$SMTP_FROM&to=JManch@protonmail.com&Subject=Restic%20${name}%20Backup%20Failure" \
                --message "${name} backup failed"
            '';
        };
      })
      backups
    );
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
      restic-remote-copy =
        let
          resticCmd = "${getExe pkgs.restic}";
          checkOpts = [ "--with-cache" ];
          pruneCmd = [
            (resticCmd + " forget --prune " + (concatStringsSep " " pruneOpts))
            (resticCmd + " check " + (concatStringsSep " " checkOpts))
          ];
        in
        {
          enable = !inputs.firstBoot.value;
          wants = [ "network-online.target" ];
          after = [ "network-online.target" ];
          onFailure = [ "restic-remote-copy-failure-notif.service" ];
          restartIfChanged = false;

          environment = {
            RESTIC_FROM_REPOSITORY_FILE = resticRepositoryFile.path;
            RESTIC_FROM_PASSWORD_FILE = resticPasswordFile.path;
            RESTIC_PASSWORD_FILE = resticPasswordFile.path;
          };

          preStart = ''
            # Initialise with copied chunker params to ensure good deduplication
            ${resticCmd} snapshots || ${resticCmd} init --copy-chunker-params
          '';

          serviceConfig = {
            Type = "oneshot";
            ExecStart = [ "${resticCmd} copy" ] ++ pruneCmd;
            ExecStartPost = "${getExe' pkgs.bash "sh"} -c '${getExe pkgs.curl} -s \"$(<${healthCheckResticRemoteCopy.path})\"'";

            EnvironmentFile = resticBackblazeVars.path;
            User = "root";
            PrivateTmp = true;
            RuntimeDirectory = "restic-remote-copy";
            CacheDirectory = "restic-remote-copy";
            CacheDirectoryMode = "0700";
          };
        };

      restic-remote-copy-failure-notif = {
        restartIfChanged = false;
        serviceConfig = {
          Type = "oneshot";
          EnvironmentFile = resticNotifVars.path;
          ExecStart =
            let
              shoutrrr = getExe outputs.packages.${pkgs.system}.shoutrrr;
            in
            pkgs.writeShellScript "restic-remote-copy-notif" ''
              ${shoutrrr} send \
                --url "discord://$DISCORD_AUTH" \
                --title "Restic Remote Copy Failed" \
                --message "Remote copy failed"

              ${shoutrrr} send \
                --url "smtp://$SMTP_USERNAME:$SMTP_PASSWORD@$SMTP_HOST:$SMTP_PORT/?from=$SMTP_FROM&to=JManch@protonmail.com&Subject=Restic%20Remote%20Copy%20Failure" \
                --message "Remote copy failed"
            '';
        };
      };
    };

    systemd.timers.restic-remote-copy = {
      # Do not enable on firstBoot of a brand new deployment because we want to
      # manually copy the remote repo first
      enable = !inputs.firstBoot.value;
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "*-*-* 01:00:00";
        Persistent = false;
      };
    };

    services.caddy.virtualHosts = {
      "restic.${fqDomain}".extraConfig = ''
        import lan_only
        reverse_proxy http://127.0.0.1:${toString cfg.server.port}
      '';
    };

    programs.zsh.shellAliases.restic-repo = "sudo -u restic restic -r ${cfg.server.dataDir}";

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
