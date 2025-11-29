{ lib, config }:
let
  port = 27701;
in
{
  requirements = [ "services.caddy" ];

  services.anki-sync-server = {
    inherit port;
    enable = true;
    address = "127.0.0.1";
    openFirewall = false;

    users = lib.singleton {
      username = "joshua";
      passwordFile = config.age.secrets.ankiSyncServerJoshua.path;
    };
  };

  systemd.services.anki-sync-server.serviceConfig = lib.${lib.ns}.hardeningBaseline config { };

  ns.services.caddy.virtualHosts.anki.extraConfig = "reverse_proxy http://127.0.0.1:${toString port}";

  ns.backups.anki-sync-server = {
    backend = "restic";
    paths = [ "/var/lib/private/anki-sync-server" ];
    restore.preRestoreScript = "sudo systemctl stop anki-sync-server";
    restore.pathOwnership."/var/lib/private/anki-sync-server" = {
      user = "nobody";
      group = "nogroup";
    };
  };

  ns.persistence.directories = lib.singleton {
    directory = "/var/lib/private/anki-sync-server";
    user = "nobody";
    group = "nogroup";
  };
}
