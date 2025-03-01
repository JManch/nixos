{
  lib,
  cfg,
  config,
}:
let
  inherit (lib) mkOption types getExe';
in
{
  requirements = [
    "services.caddy"
    "services.postgresql"
  ];

  opts.port = mkOption {
    type = types.port;
    default = 8888;
    description = "Port for the Atuin server to listen on";
  };

  services.atuin = {
    enable = true;
    openFirewall = false;
    openRegistration = false;
    host = "127.0.0.1";
    port = cfg.port;
  };

  services.postgresqlBackup.databases = [ "atuin" ];

  ns.backups.atuin-server = {
    paths = [ "/var/backup/postgresql/atuin.sql" ];

    restore =
      let
        pg_restore = getExe' config.services.postgresql.package "pg_restore";
        backup = "/var/backup/postgresql/atuin.sql";
      in
      {
        preRestoreScript = "sudo systemctl stop atuin";
        postRestoreScript = ''
          sudo -u postgres ${pg_restore} -U postgres --dbname postgres --clean --create ${backup}
        '';
      };
  };

  systemd.services.restic-backups-atuin-server = {
    requires = [ "postgresqlBackup-atuin.service" ];
    after = [ "postgresqlBackup-atuin.service" ];
  };

  ns.services.caddy.virtualHosts.atuin.extraConfig =
    "reverse_proxy http://127.0.0.1:${toString cfg.port}";
}
