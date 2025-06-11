{
  lib,
  cfg,
  pkgs,
  config,
  inputs,
  hostname,
}:
let
  inherit (lib)
    ns
    mkIf
    toUpper
    mkForce
    getExe'
    mkVMOverride
    ;
  inherit (lib.${ns}) hardeningBaseline;
  inherit (inputs.nix-resources.secrets) fqDomain;
  inherit (config.age.secrets) scrutinyVars;
  influx = getExe' pkgs.influxdb2 "influx";
in
[
  {
    enableOpt = false;
    guardType = "custom";

    opts = with lib; {
      collector.enable = mkEnableOption ''
        the Scrutiny collector service. The collector service sends data to the
        web server and can run on any machine that can access the web server.
      '';

      server = {
        enable = mkEnableOption "hosting the Scrutiny web server";

        port = mkOption {
          type = types.port;
          default = 8085;
          description = "Listen port of the web server";
        };
      };
    };
  }

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
          else
            "https://disks.${fqDomain}";
      };
    };

    systemd.services.scrutiny-collector = {
      after = [
        "network-online.target"
        "nss-lookup.target"
      ];
      wants = [ "network-online.target" ];
      requires = [ "nss-lookup.target" ];
    };
  })

  (mkIf cfg.server.enable {
    requirements = [ "services.caddy" ];

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

    systemd.services.scrutiny.serviceConfig = hardeningBaseline config {
      User = "scrutiny";
      Group = "scrutiny";
      DynamicUser = mkForce false;
      SystemCallFilter = [
        "@system-service"
        "~@privileged"
      ];
      EnvironmentFile = scrutinyVars.path;
    };

    systemd.services.scrutiny-influxdb2-backup = {
      serviceConfig = {
        Type = "oneshot";
        User = "influxdb2";
        Group = "influxdb2";
        UMask = "0077";
        ExecStart = pkgs.writeShellScript "scrutiny-influxdb2-backup" ''
          rm -rf /var/backup/influxdb2/scrutiny/*
          # NOTE: This does a full backup of the influxdb so if another
          # application uses influxdb its data will be included
          ${influx} backup /var/backup/influxdb2/scrutiny \
            -t scrutiny-default-admin-token
        '';
      };
    };

    systemd.tmpfiles.rules = [
      "d /var/backup/influxdb2 0700 influxdb2 influxdb2 - -"
      "d /var/backup/influxdb2/scrutiny 0700 influxdb2 influxdb2 - -"
    ];

    ns.backups.scrutiny = {
      backend = "restic";

      paths = [
        # Contains the sqlite DB
        "/var/lib/scrutiny"
        "/var/backup/influxdb2/scrutiny"
      ];

      restore = {
        preRestoreScript = "sudo systemctl stop scrutiny";

        postRestoreScript = # bash
          ''
            echo "Restoring Scrutiny influxdb database"
            sudo -u influxdb2 ${influx} restore /var/backup/influxdb2/scrutiny --full \
              -t scrutiny-default-admin-token
          '';

        pathOwnership = {
          "/var/lib/scrutiny" = {
            user = "scrutiny";
            group = "scrutiny";
          };
          "/var/backup/influxdb2/scrutiny" = {
            user = "influxdb2";
            group = "influxdb2";
          };
        };
      };
    };

    systemd.services.restic-backups-scrutiny = {
      requires = [ "scrutiny-influxdb2-backup.service" ];
      after = [ "scrutiny-influxdb2-backup.service" ];
    };

    ns.services.caddy.virtualHosts.disks.extraConfig = ''
      reverse_proxy http://127.0.0.1:${toString cfg.server.port}
    '';

    ns.persistence.directories = [
      {
        directory = "/var/lib/scrutiny";
        user = "scrutiny";
        group = "scrutiny";
        mode = "0750";
      }
      {
        directory = "/var/lib/influxdb2";
        user = "influxdb2";
        group = "influxdb2";
        mode = "0755";
      }
      {
        directory = "/var/backup/influxdb2/scrutiny";
        user = "influxdb2";
        group = "influxdb2";
        mode = "0750";
      }
    ];

    virtualisation.vmVariant = {
      networking.firewall.allowedTCPPorts = [ cfg.server.port ];
      services.scrutiny.settings.web.listen.host = mkVMOverride "0.0.0.0";
    };
  })
]
