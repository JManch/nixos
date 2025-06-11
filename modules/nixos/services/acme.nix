{ lib, config }:
{
  security.acme = {
    acceptTerms = true;
    defaults = {
      email = "JManch@protonmail.com";
      dnsProvider = "porkbun";
      # Because our local resolver redirects queries for our domain we have to
      # manually specify a public resolver otherwise DNS challenge fails
      dnsResolver = "1.1.1.1:53";
      environmentFile = config.age.secrets.acmePorkbunVars.path;
    };
  };

  ns.backups.acme = {
    backend = "restic";
    paths = [ "/var/lib/acme" ];
    restore.pathOwnership."/var/lib/acme" = {
      user = "acme";
      group = "acme";
    };
  };

  ns.persistence.directories = lib.singleton {
    directory = "/var/lib/acme";
    user = "acme";
    group = "acme";
    mode = "0755";
  };
}
