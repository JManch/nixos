{
  ns,
  lib,
  config,
  ...
}:
let
  inherit (lib) mkIf singleton;
  inherit (config.age.secrets) acmePorkbunVars;
  cfg = config.${ns}.services.acme;
in
mkIf cfg.enable {
  security.acme = {
    acceptTerms = true;
    defaults = {
      email = "JManch@protonmail.com";
      dnsProvider = "porkbun";
      # Because our local resolver redirects queries for our domain we have to
      # manually specify a public resolver otherwise DNS challenge fails
      dnsResolver = "1.1.1.1:53";
      environmentFile = acmePorkbunVars.path;
    };
  };

  backups.acme = {
    paths = [ "/var/lib/acme" ];
    restore.pathOwnership."/var/lib/acme" = {
      user = "acme";
      group = "acme";
    };
  };

  persistence.directories = singleton {
    directory = "/var/lib/acme";
    user = "acme";
    group = "acme";
    mode = "0755";
  };
}
