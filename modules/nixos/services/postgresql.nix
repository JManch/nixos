# How to fix database collation warnings: https://dba.stackexchange.com/a/330184
# Or: https://wiki.nixos.org/wiki/PostgreSQL#WARNING:_database_%22XXX%22_has_a_collation_version_mismatch

# Sometimes after adding a new user/database with ensureUsers and ensureDatabases this error happens:
# Relevant github issue: https://github.com/NixOS/nixpkgs/issues/318777

# postgres[1153065]: [1153065] ERROR:  template database "template1" has a collation version mismatch
# postgres[1153065]: [1153065] DETAIL:  The template database was created using collation version 2.39, but the operating system provides version 2.40.
# postgres[1153065]: [1153065] HINT:  Rebuild all objects in the template database that use the default collation and run ALTER DATABASE template1 REFRESH COLLATION VERSION, or build PostgreSQL with the right library version.

# And the postgres service fails to start. The fix is to temporarily disable ensureUsers and ensureDatabases with

# services.postgresql.ensureDatabases = lib.mkForce [ ];
# services.postgresql.ensureUsers = lib.mkForce [ ];

# Then once postgresql has successfully started run `sudo -u postgres psql` and run these commands:

# \c template1
# REINDEX DATABASE template1;
# REINDEX SYSTEM template1;
# ALTER DATABASE template1 REFRESH COLLATION VERSION;
#
# Now the ensureDatabase and ensureUsers overrides can be removed and
# postgresql should successfully start and create the new database and user

# State version upgrade procedure for a given database:

# WARN: When upgrading postgresql to a new major version, make sure to use the
# pq_dump and pq_restore binaries from the version you're upgrading to.

# - Stop home-assistant service
# - nix shell n#postgresql-<new-version>
# - sudo -i -u postgres; pg_dump -C -Fc hass | cat > /var/backup/postgresql/hass-migration-<version>.sql
# - Stop postgresql.service
# - Move /persist/var/lib/postgresql to /persist/var/lib/postgresql-<version> as a backup
# - In Nix configuration, disable the home-assistant target with `systemd.targets.home-assistant.enable = false` and upgrade the stateVersion
# - rebuild-boot the host then reboot
# - sudo -i -u postgres; pg_restore -U postgres --dbname postgres --clean --create /var/backup/...
# - Re-enable the home-assistant target then rebuild-switch
{
  lib,
  cfg,
  config,
  inputs,
}:
let
  inherit (lib)
    ns
    genAttrs
    mkIf
    mkEnableOption
    mkOption
    types
    ;
  inherit (inputs.nix-resources.secrets) fqDomain;
  certDir = config.security.acme.certs."postgres.${fqDomain}".directory;
in
{
  opts.expose = {
    enable = mkEnableOption ''
      listening on all interfaces and configuring SSL certificates. This should
      be safe since the default authentication configuration does not allow
      remote logins. Look at audiomuse module for an authentication example.
    '';

    interfaces = mkOption {
      type = with types; listOf str;
      default = [ ];
      description = ''
        List of interfaces for Postgres to be exposed on.
      '';
    };
  };

  asserts = [
    (cfg.expose.enable -> config.${ns}.services.acme.enable)
    "`expose.enable` requires ACME to be enabled"
  ];

  services.postgresql = {
    enable = true;
    enableTCPIP = cfg.expose.enable;
    settings = {
      # Version 15 enabled checkout logging by default which is quite verbose.
      # It's useful for debugging performance problems though this is unlikely
      # with my simple deployment.
      # https://git.postgresql.org/gitweb/?p=postgresql.git;a=commit;h=64da07c41a8c0a680460cdafc79093736332b6cf
      log_checkpoints = false;
      full_page_writes = mkIf (config.${ns}.hardware.file-system.type == "zfs") false;

      ssl = cfg.expose.enable;
      ssl_cert_file = mkIf cfg.expose.enable "/run/credentials/postgresql.service/cert.pem";
      ssl_key_file = mkIf cfg.expose.enable "/run/credentials/postgresql.service/key.pem";
    };
  };

  networking.firewall.interfaces = mkIf cfg.expose.enable (
    genAttrs cfg.expose.interfaces (_: {
      allowedTCPPorts = [ config.services.postgresql.settings.port ];
    })
  );

  systemd.services.postgresql = mkIf cfg.expose.enable {
    requires = [ "acme-postgres.${fqDomain}.service" ];
    after = [ "acme-postgres.${fqDomain}.service" ];
    serviceConfig.LoadCredential = [
      "cert.pem:${certDir}/fullchain.pem"
      "key.pem:${certDir}/key.pem"
    ];
  };

  security.acme.certs = mkIf cfg.expose.enable {
    "postgres.${fqDomain}".postRun = ''
      systemctl restart postgresql.service
    '';
  };

  services.postgresqlBackup = {
    enable = true;
    location = "/var/backup/postgresql";
    # -Fc enables restoring with pg_restore
    pgdumpOptions = "-C -Fc";
    # The c format is compressed by default
    compression = "none";
    # We trigger backups manually by linking to restic backup service
    startAt = [ ];
  };

  ns.persistence.directories = [
    {
      directory = "/var/lib/postgresql";
      user = "postgres";
      group = "postgres";
      mode = "0750";
    }
    {
      directory = "/var/backup/postgresql";
      user = "postgres";
      group = "postgres";
      mode = "0700";
    }
  ];
}
