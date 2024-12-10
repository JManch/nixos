{
  lib,
  config,
  inputs,
  ...
}:
let
  inherit (lib)
    ns
    mkIf
    mkMerge
    optional
    singleton
    mkForce
    ;
  inherit (lib.${ns}) asserts;
  inherit (inputs.nix-resources.secrets) fqDomain;
  inherit (config.${ns}.services) caddy mosquitto;
  inherit (config.age.secrets) zigbee2mqttYamlSecrets mqttZigbee2mqttPassword;
  inherit (config.services.zigbee2mqtt) dataDir;
  cfg = config.${ns}.services.zigbee2mqtt;
in
mkMerge [
  (mkIf cfg.enable {
    services.zigbee2mqtt = {
      enable = true;
      dataDir = "/var/lib/zigbee2mqtt";
      settings = {
        permit_join = false;
        serial = {
          port = cfg.deviceNode;
          adapter = "ember";
        };

        homeassistant = {
          enable = true;
          legacy_entity_attributes = false;
          legacy_triggers = false;
        };

        # Availability is useful for detecting when people turn off switches
        # for smart lights
        # https://www.zigbee2mqtt.io/guide/configuration/device-availability.html#device-availability
        availability = true;

        frontend = {
          host = cfg.address;
          port = cfg.port;
          url = "https://zigbee.${fqDomain}";
        };

        mqtt = {
          server = cfg.mqtt.server;
          user = "zigbee2mqtt";
          password = "!${zigbee2mqttYamlSecrets.path} password";
        };

        advanced = {
          log_level = "error";
          legacy_api = false;
          legacy_availability_payload = false;
          channel = 25;
          network_key = "!${zigbee2mqttYamlSecrets.path} network_key";
        };
      };
    };

    # Upstream module has good systemd hardening

    systemd.services.zigbee2mqtt = {
      # Fix for zigbee2mqtt hanging on shutdown due to mosquitto stopping first
      after = [ "mosquitto.service" ];
      startLimitBurst = 3;
      startLimitIntervalSec = 300;
      serviceConfig = {
        # Presumably due to instability in the ember driver the service sometimes
        # thinks the dongle has disconnected and stops gracefully
        Restart = mkForce "always";
        RestartSec = "30";
      };
    };

    networking.firewall.allowedTCPPorts = optional (!cfg.proxy.enable) cfg.port;

    backups.zigbee2mqtt = {
      paths = [ dataDir ];
      exclude = [ "log" ];
      restore.pathOwnership.${dataDir} = {
        user = "zigbee2mqtt";
        group = "zigbee2mqtt";
      };
    };

    persistence.directories = singleton {
      directory = dataDir;
      user = "zigbee2mqtt";
      group = "zigbee2mqtt";
      mode = "0700";
    };
  })

  (mkIf cfg.proxy.enable {
    assertions = asserts [
      caddy.enable
      "Zigbee2mqtt proxy requires Caddy to be enabled"
    ];

    ${ns}.services.caddy.virtualHosts.zigbee.extraConfig = ''
      basic_auth {
        admin $2a$14$6SspBEu6Yi82Bx3VdT4S1eshOACOuf4DdFlQrg2kYcDomTOrsF/ru
      }
      reverse_proxy http://${cfg.proxy.address}:${toString cfg.port}
    '';
  })

  (mkIf cfg.mqtt.user {
    assertions = asserts [
      (cfg.enable -> mosquitto.enable)
      "Zigbee2mqtt MQTT user requires Mosquitto to be enabled"
    ];

    ${ns}.services.mosquitto = {
      users = mkIf (!cfg.mqtt.tls) {
        zigbee2mqtt = {
          acl = [ "readwrite #" ];
          hashedPasswordFile = mqttZigbee2mqttPassword.path;
        };
      };

      tlsUsers = mkIf cfg.mqtt.tls {
        zigbee2mqtt = {
          acl = [ "readwrite #" ];
          hashedPasswordFile = mqttZigbee2mqttPassword.path;
        };
      };
    };
  })
]
