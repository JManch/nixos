{
  lib,
  cfg,
  pkgs,
  config,
}:
let
  inherit (lib) getExe singleton;
  inherit (config.age.secrets) mikrotikBackupKey;
  backupDir = "/var/backup/mikrotik";

  backupScript = pkgs.writeShellApplication {
    name = "mikrotik-backup-script";
    runtimeInputs = with pkgs; [
      coreutils
      openssh
      gnugrep
    ];
    text = # bash
      ''
        get_backup_file() {
          # Unfortunately I don't think there's a way to just preserve the time and not the mode
          scp -p -i ${mikrotikBackupKey.path} "backup@${cfg.routerAddress}:/$1" "${backupDir}/$1.latest"
          chmod 600 "${backupDir}/$1.latest"

          if [ -e "${backupDir}/$1" ]; then
            if [ ! "${backupDir}/$1.latest" -nt "${backupDir}/$1" ]; then
              echo "Error: new backup of $1 is not newer than the current"
              rm "${backupDir}/$1.latest"
              exit 1
            fi
            cp -p "${backupDir}/$1" "${backupDir}/$1.last"
          fi

          # cp to preserve original timestamp
          cp -p "${backupDir}/$1.latest" "${backupDir}/$1"
          rm "${backupDir}/$1.latest"
        }
        get_backup_file "export.rsc"
        get_backup_file "backup.backup"
      '';
  };
in
{
  requirements = [ "services.restic" ];

  opts = with lib; {
    routerAddress = mkOption {
      type = types.str;
      default = "router.lan";
      description = "Address of the router to fetch backup files from";
    };
  };

  users.users.mikrotik-backup = {
    group = "mikrotik-backup";
    isSystemUser = true;
  };
  users.groups.mikrotik-backup = { };

  # Failure notifications are handled by the Restic service
  systemd.services.mikrotik-backup = {
    description = "Mikrotik backup fetcher";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];

    serviceConfig = {
      Type = "oneshot";
      ExecStart = getExe backupScript;
      User = "mikrotik-backup";
      Group = "mikrotik-backup";
      UMask = "0177";
    };
  };

  systemd.services.restic-backups-mikrotik = {
    requires = [ "mikrotik-backup.service" ];
    after = [ "mikrotik-backup.service" ];
  };

  systemd.tmpfiles.rules = [
    "d ${backupDir} 0700 mikrotik-backup mikrotik-backup - -"
  ];

  backups.mikrotik = {
    paths = [ backupDir ];
    restore.pathOwnership.${backupDir} = {
      user = "mikrotik-backup";
      group = "mikrotik-backup";
    };
  };

  persistence.directories = singleton {
    directory = backupDir;
    user = "mikrotik-backup";
    group = "mikrotik-backup";
    mode = "0700";
  };
}
