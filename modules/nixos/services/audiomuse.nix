{ lib, config }:
let
  inherit (lib) foldl' getExe' singleton;
  inherit (config.age.secrets) audiomuseVars audiomuseRedisPass;
  image = "ghcr.io/neptunehub/audiomuse-ai:latest";
  ports = {
    redis = 6379; # WARN: If changing this remember to update REDIS_URL in secret env file
    postgres = config.services.postgresql.settings.port;
    # unfortunately flask port is hardcoded to 8000. Using `host` mode for
    # the containers because otherwise it's a nightmare with firewall etc...
    flask = 8000;
  };

  envVars = {
    POSTGRES_USER = "audiomuse";
    POSTGRES_DB = "audiomuse";
    POSTGRES_HOST = "127.0.0.1";
    POSTGRES_PORT = toString ports.postgres;
  };
in
{
  requirements = [
    "services.caddy"
    "services.postgresql"
    "services.navidrome"
  ];

  users.users."audiomuse" = {
    isSystemUser = true;
    group = "audiomuse";
    uid = 2000;
  };

  users.groups."audiomuse" = {
    gid = 2000;
  };

  services.redis.servers."audiomuse" = {
    enable = true;
    port = ports.redis;
    bind = "127.0.0.1";
    requirePassFile = audiomuseRedisPass.path;
  };

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
  };

  virtualisation.oci-containers.containers =
    foldl'
      (
        acc: type:
        acc
        // {
          "audiomuse-${type}" = {
            inherit image;
            environment = envVars // {
              SERVICE_TYPE = type;
            };
            environmentFiles = [ audiomuseVars.path ];
            volumes = [ "/var/cache/audiomuse/${type}:/app/temp_audio" ];
            user = "${toString config.users.users."audiomuse".uid}:${
              toString config.users.groups."audiomuse".gid
            }";
            networks = [ "host" ];
            extraOptions = [ "--security-opt=no-new-privileges" ];
          };
        }
      )
      { }
      [
        "flask"
        "worker"
      ];

  # Each track is temporarily downloaded to the temp dirs for analysis so might
  # as well reduce IO with tmpfs
  fileSystems."/var/cache/audiomuse" = {
    fsType = "tmpfs";
    options = [ "size=25%" ];
  };

  systemd.tmpfiles.rules = [
    "d /var/cache/audiomuse/worker 0750 audiomuse audiomuse - -"
    "d /var/cache/audiomuse/flask 0750 audiomuse audiomuse - -"
  ];

  systemd.services = {
    "podman-audiomuse-flask" = {
      after = [
        "postgresql.service"
        "redis-audiomuse.service"
      ];
      wants = [
        "postgresql.service"
        "redis-audiomuse.service"
      ];
    };

    "podman-audiomuse-worker" = {
      after = [
        "postgresql.service"
        "redis-audiomuse.service"
      ];
      wants = [
        "postgresql.service"
        "redis-audiomuse.service"
      ];
    };
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
}
