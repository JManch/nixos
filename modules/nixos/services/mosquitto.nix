{
  ns,
  lib,
  pkgs,
  config,
  inputs,
  ...
}:
let
  inherit (lib)
    mkIf
    mkMerge
    singleton
    ;
  inherit (inputs.nix-resources.secrets) fqDomain;
  cfg = config.${ns}.services.mosquitto;
in
mkMerge [
  (mkIf cfg.explorer.enable { environment.systemPackages = [ pkgs.mqtt-explorer ]; })
  (mkIf cfg.enable {
    assertions = lib.${ns}.asserts [
      config.${ns}.services.acme.enable
      "Mosquitto requires ACME to be enabled"
    ];

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

    # Only for cert validation. I figured that using ACME for cert generation
    # is easier than trying to get the certs out of Caddy due to
    # https://caddy.community/t/certificate-file-permissions-when-sharing-certificates/13211
    services.caddy.virtualHosts."http://mqtt.${fqDomain}".extraConfig = ''
      handle /.well-known/acme-challenge/* {
        root * /var/lib/acme/acme-challenge
        file_server
      }

      respond "Access denied" 403
    '';

    users.groups.acme.members = [ "mosquitto" ];
    security.acme.certs."mqtt.${fqDomain}" = { };

    networking.firewall.allowedTCPPorts = [
      1883
      8883
    ];

    persistence.directories = singleton {
      directory = "/var/lib/mosquitto";
      user = "mosquitto";
      group = "mosquitto";
      mode = "700";
    };
  })
]
