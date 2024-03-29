{ lib
, pkgs
, config
, inputs
, hostname
, ...
}:
let
  inherit (lib) mkIf;
  inherit (inputs.nix-resources.secrets) fqDomain;
  inherit (config.modules.services) caddy;
  cfg = config.modules.services.unifi;
in
mkIf (hostname == "homelab" && cfg.enable && caddy.enable)
{
  services.unifi = {
    enable = true;
    openFirewall = false;
    unifiPackage = pkgs.unifi8;
    # When Unifi 8.1 releases it will support MongoDB 7
    mongodbPackage = pkgs.mongodb-4_4;
  };

  networking.firewall = {
    # https://help.ubnt.com/hc/en-us/articles/218506997
    allowedTCPPorts = [
      8080 # Device communication
      6789 # UniFi mobile speed test
    ];
    allowedUDPPorts = [
      10001 # Device discovery
    ];
  };

  # Unifi module has good default systemd hardening

  services.caddy.virtualHosts."unifi.${fqDomain}".extraConfig = ''
    import lan_only
    reverse_proxy https://127.0.0.1:${toString cfg.port} {
      # We have to allow insecure HTTPS because unifi forcefully enables TLS
      # with an invalid cert.
      transport http {
        tls
        tls_insecure_skip_verify
      }
    }
  '';

  persistence.directories = [
    {
      directory = "/var/lib/unifi";
      user = "unifi";
      group = "unifi";
      mode = "700";
    }
  ];

  virtualisation.vmVariant = {
    networking.firewall.allowedTCPPorts = [ cfg.port ];
  };
}
