{ lib, config, ... }:
let
  inherit (lib) ns mkIf getExe';
  inherit (config.${ns}.services) caddy postgresql;
  cfg = config.${ns}.services.atuin-server;
in
mkIf cfg.enable {
  assertions = lib.${ns}.asserts [
    caddy.enable
    "Atuin requires Caddy to be enabled"
    postgresql.enable
    "Atuin requires postgresql to be enabled"
  ];

  services.atuin = {
    enable = true;
    openFirewall = false;
    openRegistration = false;
    host = "127.0.0.1";
    port = cfg.port;
  };

  services.postgresqlBackup.databases = [ "atuin" ];

  backups.atuin-server = {
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

  ${ns}.services.caddy.virtualHosts.atuin.extraConfig =
    "reverse_proxy http://127.0.0.1:${toString cfg.port}";
}
