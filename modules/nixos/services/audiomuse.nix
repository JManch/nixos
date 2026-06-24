{
  lib,
  cfg,
  pkgs,
  inputs,
  config,
}:
let
  inherit (lib)
    ns
    mkIf
    all
    elem
    mkMerge
    mkOption
    types
    getExe'
    mkEnableOption
    singleton
    assertMsg
    genAttrs
    optional
    optionalAttrs
    ;
  inherit (config.${ns}.services) postgresql;
  inherit (config.age.secrets) audiomuseVars audiomuseRedisPass;
  inherit (inputs.nix-resources.secrets) fqDomain;
  image = "ghcr.io/neptunehub/audiomuse-ai:latest";
  isRemoteWorker = cfg.worker.enable && !cfg.server.enable;

  ports = {
    redis = 6379; # WARN: If changing this remember to update REDIS_URL in secret env file
    redis-tls = 6380; # WARN: If changing this remember to update REDIS_URL in secret env file
    postgres = config.services.postgresql.settings.port;
    # unfortunately flask port is hardcoded to 8000. Using `host` mode for
    # the containers because otherwise it's a nightmare with firewall etc...
    flask = 8000;
  };

  envVars = {
    POSTGRES_USER = "audiomuse";
    POSTGRES_DB = "audiomuse";
    POSTGRES_HOST = if isRemoteWorker then "postgres.${fqDomain}" else "127.0.0.1";
    POSTGRES_PORT = toString ports.postgres;
  }
  // optionalAttrs isRemoteWorker {
    PGSSLMODE = "verify-full";
    PGSSLROOTCERT = "/etc/ssl/certs/ca-bundle.crt";
  };

  mkContainer = type: {
    inherit image;
    autoStart = cfg.${type}.autoStart or true;
    environment = envVars // {
      SERVICE_TYPE = type;
    };
    environmentFiles = singleton (
      if type == "worker" && isRemoteWorker then "/run/audiomuse-worker/env-vars" else audiomuseVars.path
    );
    volumes = [
      "/tmp/audiomuse-${type}:/app/temp_audio"
    ]
    ++ optional isRemoteWorker "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt:/etc/ssl/certs/ca-bundle.crt:ro";
    user = "${toString config.users.users."audiomuse".uid}:${
      toString config.users.groups."audiomuse".gid
    }";
    networks = [ "host" ];
    extraOptions = [ "--security-opt=no-new-privileges" ];
  };
in
[
  {
    enableOpt = false;

    opts = {
      server = {
        enable = mkEnableOption "hosting Audiomuse Redis server and Flask container";
        remote = {
          enable = mkEnableOption "support for remote workers";

          interfaces = mkOption {
            type = with types; listOf str;
            default = [ ];
            description = ''
              List of interfaces for the Redis server to be exposed on.
              Postgres interfaces must be manually set through its module as
              this can potentially affect other applications.
            '';
          };

          subnet = mkOption {
            type = types.str;
            default = "192.168.0.0/16";
            description = ''
              Subnet that can authenticate with the Postgresql `audiomuse`
              user. Just an extra layer of security since we are already
              password protected.
            '';
          };
        };
      };

      worker = {
        enable = mkEnableOption "Audiomuse worker";
        autoStart = mkEnableOption "auto-start" // {
          default = false;
        };
      };
    };
  }

  (mkIf (cfg.server.enable || cfg.worker.enable) {
    users.users."audiomuse" = {
      isSystemUser = true;
      group = "audiomuse";
      # `podman run --user` flag only accepts host UID or GIDs so need to statically assign these
      uid = 2000;
    };

    users.groups."audiomuse" = {
      gid = 2000;
    };
  })

  (mkIf cfg.server.enable {
    asserts = [
      (cfg.server.remote.enable -> postgresql.expose.enable)
      "`server.remote.enable` requires exposing Postgresql and ensuring it's open on the correct interface(s)"
      (
        cfg.server.remote.enable
        -> all (i: elem i postgresql.expose.interfaces) cfg.server.remote.interfaces
      )
      "all `server.remote.interfaces` must also be exposed by Postgresql"
    ];

    requirements = [
      "services.caddy"
      "services.postgresql"
    ];

    services.redis.servers."audiomuse" = {
      enable = true;
      port = ports.redis;
      bind = if cfg.server.remote.enable then null else "127.0.0.1";
      requirePassFile = audiomuseRedisPass.path;
      settings = mkIf cfg.server.remote.enable {
        tls-port = ports.redis-tls;
        tls-cert-file = "/run/credentials/redis-audiomuse.service/cert.pem";
        tls-key-file = "/run/credentials/redis-audiomuse.service/key.pem";
        tls-ca-cert-file = "/run/credentials/redis-audiomuse.service/cert.pem";
        tls-auth-clients = false;
      };
    };

    systemd.services."redis-audiomuse" = mkIf cfg.server.remote.enable {
      requires = [ "acme-redis-audiomuse.${fqDomain}.service" ];
      after = [ "acme-redis-audiomuse.${fqDomain}.service" ];
      serviceConfig.LoadCredential =
        let
          certDir = config.security.acme.certs."redis-audiomuse.${fqDomain}".directory;
        in
        [
          "cert.pem:${certDir}/fullchain.pem"
          "key.pem:${certDir}/key.pem"
        ];
    };

    security.acme.certs = mkIf cfg.server.remote.enable {
      "redis-audiomuse.${fqDomain}".postRun = ''
        systemctl restart redis-audiomuse.service
      '';
    };

    networking.firewall.interfaces = mkIf cfg.server.remote.enable (
      genAttrs cfg.server.remote.interfaces (_: {
        allowedTCPPorts = [ ports.redis-tls ];
      })
    );

    services.postgresql = {
      ensureUsers = singleton {
        name = "audiomuse";
        ensureDBOwnership = true;
        ensureClauses = {
          login = true;
          # generate with https://wiki.nixos.org/wiki/PostgreSQL#User_creation
          password = "SCRAM-SHA-256$4096:Jvbwe9kir8Rj8wo/Myd0fA==$skPGqUYPwbD93KwfEXouuks6LcpSuzvKiKD65lYXMQo=:SH063fkzLIy09bFvBSJcEF9y8Bj2GKS70fS6OztsJyI=";
        };
      };
      ensureDatabases = [ "audiomuse" ];
      authentication = mkIf cfg.server.remote.enable ''
        hostssl audiomuse audiomuse ${cfg.server.remote.subnet} scram-sha-256
      '';
    };

    virtualisation.oci-containers.containers."audiomuse-flask" = mkContainer "flask";

    systemd.tmpfiles.rules = [ "d /tmp/audiomuse-flask 0750 audiomuse audiomuse - -" ];

    systemd.services."podman-audiomuse-flask" =
      assert assertMsg (
        config.virtualisation.oci-containers.backend == "podman"
      ) "This needs a rename for new backend";
      {
        after = [
          "postgresql.target"
          "redis-audiomuse.service"
        ];
        wants = [
          "postgresql.target"
          "redis-audiomuse.service"
        ];
      };

    ns.services.caddy.virtualHosts."audiomuse".extraConfig = ''
      basic_auth {
        admin $2a$14$0IM8UG0kZ/plIFiTRQrr6.2n6yD0.l1voWjEQ8xezoQokomNJaJhq
      }
      reverse_proxy http://localhost:${toString ports.flask}
    '';

    # Config and analysis results are stored in the postgres db
    services.postgresqlBackup.databases = [ "audiomuse" ];
    ns.backups."audiomuse" = {
      backend = "restic";
      paths = [ "/var/backup/postgresql/audiomuse.sql" ];
      dependencies = [ "postgresqlBackup-audiomuse.service" ];
      restore =
        let
          pg_restore = getExe' config.services.postgresql.package "pg_restore";
        in
        {
          postRestoreScript = ''
            sudo -u postgres ${pg_restore} -U postgres --dbname postgres --clean --create /var/backup/postgresql/audiomuse.sql
          '';
        };
    };

    ns.persistence.directories = [
      {
        directory = "/var/lib/redis-audiomuse";
        user = "redis-audiomuse";
        group = "redis-audiomuse";
        mode = "0700";
      }
    ];
  })

  (mkIf cfg.worker.enable {
    virtualisation.oci-containers.containers."audiomuse-worker" = mkContainer "worker";

    systemd.tmpfiles.rules = [ "d /tmp/audiomuse-worker 0750 audiomuse audiomuse - -" ];

    systemd.services."podman-audiomuse-worker" =
      assert assertMsg (
        config.virtualisation.oci-containers.backend == "podman"
      ) "This needs a rename for new backend";
      mkMerge [
        {
          serviceConfig.ExecStartPre = mkIf isRemoteWorker (
            pkgs.writeShellScript "setup-audiomuse-vars" ''
              sed '/REDIS_URL/d' ${audiomuseVars.path} > /run/audiomuse-worker/env-vars
              sed 's/REDIS_REMOTE_URL/REDIS_URL/' -i /run/audiomuse-worker/env-vars
            ''
          );
        }

        (mkIf cfg.server.enable {
          after = [
            "postgresql.target"
            "redis-audiomuse.service"
          ];

          wants = [
            "postgresql.target"
            "redis-audiomuse.service"
          ];
        })
      ];
  })
]
