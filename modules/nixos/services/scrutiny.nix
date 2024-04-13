{ lib
, config
, inputs
, hostname
, ...
}:
let
  inherit (lib) mkIf mkMerge utils toUpper mkForce;
  inherit (inputs.nix-resources.secrets) fqDomain;
  inherit (config.modules.services) caddy;
  inherit (config.age.secrets) scrutinyVars;
  cfg = config.modules.services.scrutiny;
in
mkMerge [
  (mkIf cfg.collector.enable {
    services.scrutiny.collector = {
      enable = cfg.collector.enable;
      # Run every 6 hours
      schedule = "*-*-* 00/6:00:00";

      settings = {
        host.id = toUpper hostname;
        api.endpoint = "https://disks.${fqDomain}";
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
          port = cfg.port;
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

    services.caddy.virtualHosts."disks.${fqDomain}".extraConfig = ''
      import lan_only
      reverse_proxy http://127.0.0.1:${toString cfg.port}
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
    ];
  })
]
