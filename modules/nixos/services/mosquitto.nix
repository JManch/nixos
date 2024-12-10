{
  lib,
  pkgs,
  config,
  inputs,
  ...
}:
let
  inherit (lib)
    ns
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
      mode = "0700";
    };
  })
]
