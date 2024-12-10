# How to fix database collation warnings: https://dba.stackexchange.com/a/330184

# State version upgrade procedure:

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
{ lib, config, ... }:
let
  inherit (lib) ns mkIf;
  cfg = config.${ns}.services.postgresql;
in
mkIf cfg.enable {
  services.postgresql = {
    enable = true;
    # Version 15 enabled checkout logging by default which is quite verbose.
    # It's useful for debugging performance problems though this is unlikely
    # with my simple deployment.
    # https://git.postgresql.org/gitweb/?p=postgresql.git;a=commit;h=64da07c41a8c0a680460cdafc79093736332b6cf
    settings = {
      log_checkpoints = false;
      full_page_writes = mkIf (config.${ns}.hardware.fileSystem.type == "zfs") false;
    };
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

  persistence.directories = [
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
