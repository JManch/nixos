{
  lib,
  cfg,
  pkgs,
  config,
  inputs,
}:
let
  inherit (lib) mkIf singleton;
  inherit (inputs.nix-resources.secrets) fqDomain;
in
[
  {
    guardType = "first";
    requirements = [ "services.acme" ];

    opts = with lib; {
      explorer.enable = mkEnableOption "MQTT Explorer";

      users = mkOption {
        type = types.attrs;
        default = { };
        example = literalExpression ''
          {
            frigate = {
              acl = [ "readwrite #" ];
              hashedPasswordFile = mqttFrigatePassword.path;
            };
          }
        '';
      };

      tlsUsers = mkOption {
        type = types.attrs;
        default = { };
        example = literalExpression ''
          {
            frigate = {
              acl = [ "readwrite #" ];
              hashedPasswordFile = mqttFrigatePassword.path;
            };
          }
        '';
      };
    };

    services.mosquitto = {
      enable = true;
      listeners = [
        {
          # Unencrypted listener. Only use on localhost and trusted LAN.
          port = 1883;
          users = cfg.users;
          settings.allow_anonymous = false;
        }
        {
          # TLS listener
          port = 8883;
          users = cfg.tlsUsers;
          settings =
            let
              certDir = config.security.acme.certs."mqtt.${fqDomain}".directory;
            in
            {
              allow_anonymous = false;
              certfile = "${certDir}/cert.pem";
              keyfile = "${certDir}/key.pem";
              cafile = "${certDir}/chain.pem";
            };
        }
      ];
    };

    users.groups.acme.members = [ "mosquitto" ];
    security.acme.certs."mqtt.${fqDomain}" = { };

    networking.firewall.allowedTCPPorts = [
      1883
      8883
    ];

    ns.persistence.directories = singleton {
      directory = "/var/lib/mosquitto";
      user = "mosquitto";
      group = "mosquitto";
      mode = "0700";
    };
  }

  (mkIf cfg.explorer.enable { ns.userPackages = [ pkgs.mqtt-explorer ]; })
]
