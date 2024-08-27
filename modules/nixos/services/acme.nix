{ lib, config, ... }:
let
  inherit (lib) mkIf singleton;
  cfg = config.modules.services.acme;
in
mkIf cfg.enable {
  security.acme = {
    acceptTerms = true;
    defaults.email = "JManch@protonmail.com";
    defaults.webroot = "/var/lib/acme/acme-challenge";
  };

  backups.acme = {
    paths = [ "/var/lib/acme" ];
    restore.pathOwnership = {
      "/var/lib/acme" = {
        user = "acme";
        group = "acme";
      };
    };
  };

  persistence.directories = singleton {
    directory = "/var/lib/acme";
    user = "acme";
    group = "acme";
    mode = "755";
  };
}
