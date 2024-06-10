{ lib
, pkgs
, config
, inputs
, hostname
, ...
}:
let
  inherit (lib) mkIf utils;
  inherit (inputs.nix-resources.secrets) fqDomain;
  inherit (config.modules.services) caddy;
  cfg = config.modules.services.unifi;
in
mkIf cfg.enable
{
  assertions = utils.asserts [
    (hostname == "homelab")
    "Unifi is only intended to work on host 'homelab'"
    caddy.enable
    "Frigate requires Caddy to be enabled"
  ];

  # WARN: Firmware version 6.6.65 seems to have a bug that causes my APs to
  # intermittently go offline/lose adopting in the controller. Using 6.6.55
  # until new firmware fixes this.
  services.unifi = {
    enable = true;
    openFirewall = false;
    unifiPackage = pkgs.unifi8.overrideAttrs (_: {
      src = pkgs.fetchurl {
        url = "https://dl.ubnt.com/unifi/8.2.93-1c329ecd26/unifi_sysvinit_all.deb";
        sha256 = "sha256-7zcRxflEvPRxH7MtudOqumeUpSzAaEIbjaaJVpr2Gbc=";
      };
    });
    # WARN: Be careful when changing mongodb versions as mongodb requires
    # manual intervention to migrate. Safest method is to export a unifi
    # backup, clear /var/lib/unifi and then restore from backup.
    mongodbPackage = pkgs.mongodb-6_0;
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
    import lan-only
    reverse_proxy https://127.0.0.1:8443 {
      # We have to allow insecure HTTPS because unifi forcefully enables TLS
      # with an invalid cert.
      transport http {
        tls
        tls_insecure_skip_verify
      }
    }
  '';

  # WARN: Auto-backups have to be configured in the UI
  backups.unifi = {
    paths = [ "/var/lib/unifi/data/backup/autobackup" ];
    restore.pathOwnership = {
      "/var/lib/unifi/data/backup/autobackup" = { user = "unifi"; group = "unifi"; };
    };
  };

  persistence.directories = [{
    directory = "/var/lib/unifi";
    user = "unifi";
    group = "unifi";
    mode = "750";
  }];

  virtualisation.vmVariant = {
    networking.firewall.allowedTCPPorts = [ 8443 ];
  };
}
