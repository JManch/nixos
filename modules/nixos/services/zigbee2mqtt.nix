{
  lib,
  pkgs',
  config,
  inputs,
  ...
}:
let
  inherit (lib)
    mkIf
    utils
    singleton
    mkForce
    ;
  inherit (inputs.nix-resources.secrets) fqDomain;
  inherit (config.modules.services) caddy mosquitto;
  inherit (caddy) allowAddresses trustedAddresses;
  inherit (config.age.secrets) zigbee2mqttYamlSecrets mqttZigbee2mqttPassword;
  inherit (config.services.zigbee2mqtt) dataDir;
  cfg = config.modules.services.zigbee2mqtt;
in
mkIf cfg.enable {
  assertions = utils.asserts [
    (cfg.enable -> mosquitto.enable)
    "Zigbee2mqtt requires mosquitto to be enabled"
    (cfg.enable -> caddy.enable)
    "Zigbee2mqtt requires caddy to be enabled"
  ];

  services.zigbee2mqtt = {
    enable = true;
    package = pkgs'.zigbee2mqtt;
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

      # Availability is useful for detecting when people turn off switches for
      # smart lights. Once all our switches get replaced with smart ones I can
      # disable this. I've changed the default active timeout from 10 to 5
      # mins.
      availability = {
        active.timeout = 5;
        passive.timeout = 1500;
      };

      frontend = {
        host = "127.0.0.1";
        port = cfg.port;
        url = "https://zigbee.${fqDomain}";
      };

      mqtt = {
        server = "mqtt://127.0.0.1:1883";
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
    startLimitBurst = 3;
    startLimitIntervalSec = 60;
    serviceConfig = {
      # Presumably due to instability in the ember driver the service sometimes
      # thinks the dongle has disconnected and stops gracefully
      Restart = mkForce "always";
      RestartSec = "30";
    };
  };

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
    restore.pathOwnership.${dataDir} = {
      user = "zigbee2mqtt";
      group = "zigbee2mqtt";
    };
  };

  persistence.directories = singleton {
    directory = dataDir;
    user = "zigbee2mqtt";
    group = "zigbee2mqtt";
    mode = "770";
  };
}
