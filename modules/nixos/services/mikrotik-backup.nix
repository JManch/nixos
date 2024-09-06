{
  ns,
  lib,
  pkgs,
  config,
  ...
}:
let
  inherit (lib)
    mkIf
    getExe
    singleton
    ;
  inherit (config.age.secrets) mikrotikBackupKey;
  cfg = config.${ns}.services.mikrotik-backup;
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
mkIf cfg.enable {
  assertions = lib.${ns}.asserts [
    config.${ns}.services.restic.enable
    "Mikrotik backup requires Restic backups to be enabled"
  ];

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

  backups.mikrotik = {
    paths = [ backupDir ];
    restore.pathOwnership = {
      "${backupDir}" = {
        user = "mikrotik-backup";
        group = "mikrotik-backup";
      };
    };
  };

  persistence.directories = singleton {
    directory = backupDir;
    user = "mikrotik-backup";
    group = "mikrotik-backup";
    mode = "700";
  };
}
