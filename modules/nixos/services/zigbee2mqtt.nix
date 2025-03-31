{
  lib,
  cfg,
  pkgs,
  config,
  inputs,
}:
let
  inherit (lib)
    ns
    mkIf
    optional
    singleton
    mkForce
    mkEnableOption
    mkOption
    types
    ;
  inherit (inputs.nix-resources.secrets) fqDomain;
  inherit (config.${ns}.services) mosquitto home-assistant;
  inherit (config.age.secrets) zigbee2mqttYamlSecrets mqttZigbee2mqttPassword;
  inherit (config.services.zigbee2mqtt) dataDir;
in
[
  {
    guardType = "first";

    opts = {
      mqtt = {
        user = mkEnableOption "Zigbee2mqtt Mosquitto user";
        tls = mkEnableOption "TLS Mosquitto user";

        server = mkOption {
          type = types.str;
          default = "mqtt://127.0.0.1:1883";
          description = "MQTT server address";
        };
      };

      proxy = {
        enable = mkEnableOption "proxying Zigbee2mqtt";

        address = mkOption {
          type = types.str;
          default = "127.0.0.1";
          description = "Frontend proxy address";
        };

        port = mkOption {
          type = types.port;
          default = cfg.zigbee2mqtt.port;
          description = "Frontend proxy port";
        };
      };

      port = mkOption {
        type = types.port;
        default = 8084;
        description = "Port of the frontend web interface";
      };

      address = mkOption {
        type = types.str;
        default = "127.0.0.1";
        description = "Address for the frontend web interface to listen on";
      };

      deviceNode = mkOption {
        type = types.str;
        example = "/dev/ttyUSB0";
        description = "The device node of the zigbee adapter.";
      };
    };

    services.zigbee2mqtt = {
      enable = true;
      package = pkgs.zigbee2mqtt_2;
      dataDir = "/var/lib/zigbee2mqtt";
      settings = {
        homeassistant.enabled = home-assistant.enable;

        # Availability is useful for detecting when people turn off switches
        # for smart lights
        # https://www.zigbee2mqtt.io/guide/configuration/device-availability.html#device-availability
        availability.enabled = true;

        serial = {
          port = cfg.deviceNode;
          adapter = "ember";
        };

        frontend = {
          enabled = true;
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
        RestartSec = 30;
      };
    };

    networking.firewall.allowedTCPPorts = optional (!cfg.proxy.enable) cfg.port;

    ns.backups.zigbee2mqtt = {
      paths = [ dataDir ];
      exclude = [ "log" ];
      restore.pathOwnership.${dataDir} = {
        user = "zigbee2mqtt";
        group = "zigbee2mqtt";
      };
    };

    ns.persistence.directories = singleton {
      directory = dataDir;
      user = "zigbee2mqtt";
      group = "zigbee2mqtt";
      mode = "0700";
    };
  }

  (mkIf cfg.proxy.enable {
    requirements = [ "services.caddy" ];

    ns.services.caddy.virtualHosts.zigbee.extraConfig = ''
      basic_auth {
        admin $2a$14$6SspBEu6Yi82Bx3VdT4S1eshOACOuf4DdFlQrg2kYcDomTOrsF/ru
      }
      reverse_proxy http://${cfg.proxy.address}:${toString cfg.port}
    '';
  })

  (mkIf cfg.mqtt.user {
    asserts = [
      (cfg.enable -> mosquitto.enable)
      "Zigbee2mqtt MQTT user requires Mosquitto to be enabled"
    ];

    ns.services.mosquitto = {
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
