{
  lib,
  cfg,
  pkgs,
  config,
}:
{
  opts = with lib; {
    port = mkOption {
      type = types.port;
      default = 3000;
      description = "Port for the sliverbullet to listen on";
    };

    allowedAddresses = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "List of address to give access to silverbullet";
    };
  };

  requirements = [ "services.caddy" ];

  # The upstream module sucks
  systemd.services."silverbullet" = {
    description = "SilverBullet Server";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = lib.${lib.ns}.hardeningBaseline config {
      EnironmentFile = config.age.secrets.silverbulletVars.path;
      StateDirectory = "silverbullet";
      ExecStart = "${
        lib.getExe pkgs.${lib.ns}.silverbullet
      } --port ${toString cfg.port} --hostname 127.0.0.1 $STATE_DIRECTORY";
      Restart = "on-failure";
      RestartSec = 10;
      # Make file system inaccessible
      TemporaryFileSystem = "/";
      BindReadOnlyPaths = [ builtins.storeDir ];
    };
  };

  ns.services.caddy.virtualHosts."notes" = {
    allowTrustedAddresses = false;
    extraAllowedAddresses = cfg.allowedAddresses;
    extraConfig = ''
      reverse_proxy http://127.0.0.1:${toString cfg.port}
    '';
  };

  ns.backups."silverbullet" = {
    backend = "restic";
    paths = [ "/var/lib/private/silverbullet" ];
    restore.preRestoreScript = "sudo systemctl stop silverbullet";
    restore.pathOwnership."/var/lib/private/silverbullet" = {
      user = "nobody";
      group = "nogroup";
    };
  };

  ns.persistence.directories = lib.singleton {
    directory = "/var/lib/private/silverbullet";
    user = "nobody";
    group = "nogroup";
  };
}
