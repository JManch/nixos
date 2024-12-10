{ lib, config, ... }:
let
  inherit (lib) ns mkIf singleton;
  inherit (lib.${ns}) asserts hardeningBaseline;
  inherit (config.${ns}.services) caddy;
  cfg = config.${ns}.services.taskchampion-server;
in
mkIf cfg.enable {
  assertions = asserts [
    caddy.enable
    "Taskchampion server requires Caddy to be enabled"
  ];

  services.taskchampion-sync-server = {
    enable = true;
    port = cfg.port;
  };

  systemd.services.taskchampion-sync-server.serviceConfig = hardeningBaseline config {
    DynamicUser = false;
    StateDirectory = "taskchampion-sync-server";
  };

  ${ns}.services.caddy.virtualHosts.tasks.extraConfig = ''
    reverse_proxy http://127.0.0.1:${toString cfg.port}
  '';

  backups.taskchampion-server = {
    paths = [ "/var/lib/taskchampion-sync-server" ];
    restore.pathOwnership."/var/lib/taskchampion-sync-server" = {
      user = "taskchampion";
      group = "taskchampion";
    };
  };

  persistence.directories = singleton {
    directory = "/var/lib/taskchampion-sync-server";
    user = "taskchampion";
    group = "taskchampion";
    mode = "0750";
  };
}
