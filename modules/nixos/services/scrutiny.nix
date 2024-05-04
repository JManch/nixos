{ lib
, pkgs
, config
, inputs
, hostname
, ...
}:
let
  inherit (lib) mkIf mkMerge utils toUpper mkForce getExe' getExe mkVMOverride;
  inherit (inputs.nix-resources.secrets) fqDomain;
  inherit (config.modules.services) caddy;
  inherit (config.age.secrets) scrutinyVars;
  cfg = config.modules.services.scrutiny;
  influx = getExe' pkgs.influxdb2 "influx";
in
mkMerge [
  (mkIf cfg.collector.enable {
    services.scrutiny.collector = {
      enable = cfg.collector.enable;
      # Run every 6 hours
      schedule = "*-*-* 00/6:00:00";

      settings = {
        host.id = toUpper hostname;
        api.endpoint =
          if cfg.server.enable then
            "http://127.0.0.1:${toString cfg.server.port}"
          else "https://disks.${fqDomain}";
      };
    };

    systemd.services.scrutiny-collectors = {
      after = [ "network-online.target" "nss-lookup.target" ];
      wants = [ "network-online.target" "nss-lookup.target" ];
      serviceConfig = {
        # Workaround to ensure the service starts after DNS resolution is ready
        ExecStartPre =
          let
            sh = getExe' pkgs.bash "sh";
            host = getExe' pkgs.host "host";
            sleep = getExe' pkgs.coreutils "sleep";
          in
          "${sh} -c 'while ! ${host} ${fqDomain}; do ${sleep} 1; done'";
      };
    };
  })

  (mkIf cfg.server.enable {
    assertions = utils.asserts [
      caddy.enable
      "Scrutiny server requires Caddy to be enabled"
    ];

    services.scrutiny = {
      enable = true;

      settings = {
        web.listen = {
          host = "127.0.0.1";
          port = cfg.server.port;
        };

        # The default database API token is "scrutiny-default-admin-token"
        # https://github.com/AnalogJ/scrutiny/blob/master/docs/TROUBLESHOOTING_INFLUXDB.md#customize-influxdb-admin-username--password
        web.influxdb = {
          org = "scrutiny";
          bucket = "scrutiny-bucket";
        };
      };
    };

    users.users.scrutiny = {
      group = "scrutiny";
      isSystemUser = true;
    };

    users.groups.scrutiny = { };

    systemd.services.scrutiny.serviceConfig = utils.hardeningBaseline config {
      User = "scrutiny";
      Group = "scrutiny";
      DynamicUser = mkForce false;
      SystemCallFilter = [ "@system-service" "~@privileged" ];
      EnvironmentFile = scrutinyVars.path;
    };

    systemd.services.scrutiny-influxdb2-backup = {
      serviceConfig = {
        Type = "oneshot";
        User = "influxdb2";
        Group = "influxdb2";
        ExecStart = pkgs.writeShellScript "scrutiny-influxdb2-backup" ''
          rm -rf /var/backup/influxdb2/scrutiny/*
          # NOTE: This does a full backup of the influxdb so if another
          # application uses influxdb its data will be included
          ${influx} backup /var/backup/influxdb2/scrutiny \
            -t scrutiny-default-admin-token
        '';
      };
    };

    backups.scrutiny = {
      paths = [
        # Contains the sqlite DB
        "/var/lib/scrutiny"
        "/var/backup/influxdb2/scrutiny"
      ];

      restore = {
        preRestoreScript = /*bash*/ ''
          sudo ${getExe' pkgs.systemd "systemctl"} stop scrutiny
        '';

        postRestoreScript = /*bash*/ ''
          echo "Restoring Scrutiny influxdb database"
          sudo -u influxdb2 ${influx} restore /var/backup/influxdb2/scrutiny --full \
            -t scrutiny-default-admin-token
        '';

        pathOwnership = {
          "/var/lib/scrutiny" = { user = "scrutiny"; group = "scrutiny"; };
          "/var/backup/influxdb2/scrutiny" = { user = "influxdb2"; group = "influxdb2"; };
        };
      };
    };

    systemd.services.restic-backups-scrutiny = {
      requires = [ "scrutiny-influxdb2-backup.service" ];
      after = [ "scrutiny-influxdb2-backup.service" ];
    };

    services.caddy.virtualHosts."disks.${fqDomain}".extraConfig = ''
      import lan_only
      reverse_proxy http://127.0.0.1:${toString cfg.server.port}
    '';

    persistence.directories = [
      {
        directory = "/var/lib/scrutiny";
        user = "scrutiny";
        group = "scrutiny";
        mode = "750";
      }
      {
        directory = "/var/lib/influxdb2";
        user = "influxdb2";
        group = "influxdb2";
        mode = "750";
      }
      {
        directory = "/var/backup/influxdb2/scrutiny";
        user = "influxdb2";
        group = "influxdb2";
        mode = "750";
      }
    ];

    virtualisation.vmVariant = {
      networking.firewall.allowedTCPPorts = [ cfg.server.port ];
      services.scrutiny.settings.web.listen.host = mkVMOverride "0.0.0.0";
    };
  })
]
