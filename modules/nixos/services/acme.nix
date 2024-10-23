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
