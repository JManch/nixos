{ lib, config, inputs, ... }:
let
  inherit (lib) mkIf;
  inherit (inputs.nix-resources.secrets) fqDomain;
  cfg = config.modules.services.vaultwarden;
in
mkIf cfg.enable
{
  services.vaultwarden = {
    enable = true;
    # Backup runs everyday at 11pm
    backupDir = "/var/backup/vaultwarden";
    config = {
      # Reference: https://github.com/dani-garcia/vaultwarden/blob/1.30.5/.env.template
      DOMAIN = "https://bitwarden.${fqDomain}";
      SIGNUPS_ALLOWED = false;
      INVITATIONS_ALLOWED = true;
      ROCKET_PORT = cfg.port;
    };
  };

  services.caddy.virtualHosts = {
    # TODO: Eventually add TLS auth
    # tls {
    #   client_auth {
    #     mode require_and_verify
    #     trusted_ca_cert_file ${config.age.secrets.rootCA.path}
    #     trusted_leaf_cert_file ${config.age.secrets.homeCert.path}
    #   }
    # }
    "bitwarden.${fqDomain}".extraConfig = ''
      reverse_proxy http://127.0.0.1:${toString cfg.port}
    '';
  };

  persistence.directories = [
    {
      directory = "/var/lib/bitwarden_rs";
      user = "vaultwarden";
      group = "vaultwarden";
      mode = "770";
    }
    {
      directory = "/var/backup/vaultwarden";
      user = "vaultwarden";
      group = "vaultwarden";
      mode = "770";
    }
  ];
}
