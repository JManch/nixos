{ lib, config }:
let
  inherit (lib) getExe' singleton;
  inherit (config.age.secrets) audiomuseVars audiomuseRedisPass;
  image = "ghcr.io/neptunehub/audiomuse-ai:latest";
  ports = {
    redis = 6379; # WARN: If changing this remember to update REDIS_URL in secret env file
    postgres = config.services.postgresql.settings.port;
    # unfortunately flask port is hardcoded to 8000. Not using `host` mode for
    # the containers because it's a nightmare with firewall etc...
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

  virtualisation.oci-containers.containers = {
    "audiomuse-flask" = {
      inherit image;
      environment = envVars // {
        SERVICE_TYPE = "flask";
      };
      environmentFiles = [ audiomuseVars.path ];
      volumes = [ "/var/cache/audiomuse-flask:/app/temp_audio" ];
      user = "${toString config.users.users."audiomuse".uid}:${
        toString config.users.groups."audiomuse".gid
      }";
      networks = [ "host" ];
      extraOptions = [ "--security-opt=no-new-privileges" ];
    };

    "audiomuse-worker" = {
      inherit image;
      environment = envVars // {
        SERVICE_TYPE = "worker";
      };
      environmentFiles = [ audiomuseVars.path ];
      volumes = [ "/var/cache/audiomuse-worker:/app/temp_audio" ];
      user = "${toString config.users.users."audiomuse".uid}:${
        toString config.users.groups."audiomuse".gid
      }";
      networks = [ "host" ];
      extraOptions = [ "--security-opt=no-new-privileges" ];
    };
  };

  # Not using serviceConfig.CacheDirectory because ownership would be root
  systemd.tmpfiles.rules = [
    "d /var/cache/audiomuse-worker 0750 audiomuse audiomuse - -"
    "d /var/cache/audiomuse-flask 0750 audiomuse audiomuse - -"
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
      directory = "/var/cache/audiomuse-flask";
      user = "audiomuse";
      group = "audiomuse";
      mode = "0750";
    }
    {
      directory = "/var/cache/audiomuse-worker";
      user = "audiomuse";
      group = "audiomuse";
      mode = "0750";
    }
    {
      directory = "/var/lib/redis-audiomuse";
      user = "redis-audiomuse";
      group = "redis-audiomuse";
      mode = "0700";
    }
  ];
}
