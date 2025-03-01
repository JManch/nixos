{
  lib,
  cfg,
  config,
}:
let
  inherit (lib) ns singleton;
in
{
  requirements = [ "services.caddy" ];

  opts.port =
    with lib;
    mkOption {
      type = types.port;
      default = 10222;
      description = "Port for the Taskchampion server to listen on";
    };

  services.taskchampion-sync-server = {
    enable = true;
    port = cfg.port;
  };

  systemd.services.taskchampion-sync-server.serviceConfig = lib.${ns}.hardeningBaseline config {
    DynamicUser = false;
    StateDirectory = "taskchampion-sync-server";
  };

  ns.services.caddy.virtualHosts.tasks.extraConfig = ''
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
