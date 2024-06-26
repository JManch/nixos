{ lib, config, inputs, ... }:
let
  inherit (lib) mkIf utils;
  inherit (inputs.nix-resources.secrets) fqDomain;
  inherit (config.modules.services) caddy mosquitto;
  inherit (caddy) allowAddresses trustedAddresses;
  inherit (config.age.secrets) zigbee2mqttYamlSecrets mqttZigbee2mqttPassword;
  inherit (config.services.zigbee2mqtt) dataDir;
  cfg = config.modules.services.zigbee2mqtt;
in
mkIf cfg.enable
{
  assertions = utils.asserts [
    (cfg.enable -> mosquitto.enable)
    "Zigbee2mqtt requires mosquitto to be enabled"
    (cfg.enable -> caddy.enable)
    "Zigbee2mqtt requires caddy to be enabled"
  ];

  services.zigbee2mqtt = {
    enable = true;
    dataDir = "/var/lib/zigbee2mqtt";
    settings = {
      permit_join = false;
      serial.port = cfg.deviceNode;

      homeassistant = {
        enable = true;
        legacy_entity_attributes = false;
        legacy_triggers = false;
      };

      frontend = {
        host = "127.0.0.1";
        port = cfg.port;
        url = "https://zigbee.${fqDomain}";
      };

      mqtt = {
        server = "mqtt://127.0.0.1:${toString mosquitto.port}";
        user = "zigbee2mqtt";
        password = "!${zigbee2mqttYamlSecrets.path} password";
      };

      advanced = {
        log_level = "warn";
        legacy_api = false;
        network_key = "!${zigbee2mqttYamlSecrets.path} network_key";
      };
    };
  };

  # Upstream module has good systemd hardening

  modules.services.mosquitto.users = {
    zigbee2mqtt = {
      acl = [ "readwrite #" ];
      hashedPasswordFile = mqttZigbee2mqttPassword.path;
    };
  };

  services.caddy.virtualHosts = {
    "zigbee.${fqDomain}".extraConfig = ''
      ${allowAddresses trustedAddresses}
      basic_auth {
        admin $2a$14$6SspBEu6Yi82Bx3VdT4S1eshOACOuf4DdFlQrg2kYcDomTOrsF/ru
      }
      reverse_proxy http://127.0.0.1:${toString cfg.port}
    '';
  };

  backups.zigbee2mqtt = {
    paths = [ dataDir ];
    exclude = [ "log" ];
    restore.pathOwnership.${dataDir} = { user = "zigbee2mqtt"; group = "zigbee2mqtt"; };
  };

  persistence.directories = [{
    directory = dataDir;
    user = "zigbee2mqtt";
    group = "zigbee2mqtt";
    mode = "770";
  }];
}
