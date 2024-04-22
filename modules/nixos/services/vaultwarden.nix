{ lib
, pkgs
, config
, inputs
, outputs
, ...
}:
let
  inherit (lib) mkIf getExe mkForce mkVMOverride optional utils;
  inherit (config.modules.system.virtualisation) vmVariant;
  inherit (inputs.nix-resources.secrets) fqDomain;
  inherit (config.modules.services) caddy;
  inherit (config.age.secrets)
    rcloneConfig
    vaultwardenVars
    vaultwardenSMTPVars
    vaultwardenPublicBackupKey;
  cfg = config.modules.services.vaultwarden;

  restoreScript = pkgs.writeShellApplication {
    name = "vaultwarden-restore-backup";
    runtimeInputs = with pkgs; [
      coreutils
      age
      bzip2
      gnutar
      systemd
    ];
    text = /*bash*/ ''

      if [ "$#" -ne 2 ]; then
        echo "Usage: vaultwarden-restore-backup <backup> <encrypted_private_key>"
        exit 1
      fi

      if [ "$(id -u)" != "0" ]; then
         echo "This script must be run as root" 1>&2
         exit 1
      fi

      backup=$1
      key=$2
      vault="/var/lib/bitwarden_rs"

      if ! [ -d "$vault" ]; then
        echo "Error: The vaultwarden state directory $vault does not exist"
        exit 1
      fi

      if ! [ -e "$backup" ]; then
        echo "Error: $backup file does not exist"
        exit 1
      fi

      if ! [ -e "$key" ]; then
        echo "Error: $key file does not exist"
        exit 1
      fi

      echo "WARNING: All data in the current vault ($vault) will be destroyed and replaced with the backup"
      read -p "Are you sure you want to proceed? (y/N): " -n 1 -r
      echo
      if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
          echo "Aborting"
          exit 1
      fi;

      echo "Hash: $(sha256sum "$backup")"
      read -p "Does the hash match the expected value? (compare with both email and the hash file) (y/N): " -n 1 -r
      echo
      if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
          echo "Aborting"
          exit 1
      fi;

      systemctl stop vaultwarden
      rm -rf "''${vault:?}/"*

      age -d "$key" | age -d -i - "$backup" | tar -xjf - -C "$vault"

      chown -R vaultwarden:vaultwarden "$vault"
      echo "Vault successfully restored. The vaultwarden service must be manually started again."

    '';
  };
in
mkIf cfg.enable
{
  assertions = utils.asserts [
    caddy.enable
    "Vaultwarden requires Caddy to be enabled"
  ];

  services.vaultwarden = {
    enable = true;
    backupDir = "/var/backup/vaultwarden";
    environmentFile = vaultwardenVars.path;

    config = {
      # Reference: https://github.com/dani-garcia/vaultwarden/blob/1.30.5/.env.template
      DOMAIN = "https://vaultwarden.${fqDomain}";
      SIGNUPS_ALLOWED = false;
      INVITATIONS_ALLOWED = false;
      SHOW_PASSWORD_HINT = false;
      ROCKET_PORT = cfg.port;
    };
  };

  systemd.services.vaultwarden.serviceConfig = utils.hardeningBaseline config {
    DynamicUser = false;
    # Because upstream module annoyingly uses strings instead of bools...
    PrivateDevices = mkForce true;
    PrivateTmp = mkForce true;
    ProtectHome = mkForce true;
    AmbientCapabilities = mkForce "";
    EnvironmentFile = (optional (!vmVariant) vaultwardenSMTPVars.path)
      ++ (optional (!cfg.adminInterface) (pkgs.writeText "vaultwarden-disable-admin" ''
      ADMIN_TOKEN=""
    ''));
  };

  # Run backup twice a day
  systemd.timers.backup-vaultwarden.timerConfig.OnCalendar = "08,20:00";
  systemd.services.backup-vaultwarden.wantedBy = mkForce [ ];

  environment.systemPackages = [ restoreScript ];

  # TODO: Implement proper backup failure notify system with something like
  # this https://healthchecks.io/

  systemd.services.vaultwarden-cloud-backup =
    let
      inherit (config.services.vaultwarden) backupDir;
      publicKey = vaultwardenPublicBackupKey.path;
      cloudBackupScript = pkgs.writeShellApplication {
        name = "vaultwarden-cloud-backup";
        runtimeInputs = with pkgs; [
          coreutils
          diffutils
          gnutar
          bzip2
          age
          rclone
          outputs.packages.${pkgs.system}.shoutrrr
        ];
        text = /*bash*/ ''

          set -o errtrace
          time=$(date +%s)

          send_notification() {
            if [ "$1" = "Failure" ]; then
              discord_auth=$DISCORD_AUTH_FAILURE
            else
              discord_auth=$DISCORD_AUTH_SUCCESS
            fi

            shoutrrr send \
              --url "discord://$discord_auth" \
              --title "Vaultwarden Backup $1 $time" \
              --message "$2"

            shoutrrr send \
              --url "smtp://$SMTP_URL_USERNAME:$SMTP_PASSWORD@$SMTP_HOST:$SMTP_PORT/?from=$SMTP_FROM&to=JManch@protonmail.com&Subject=Vaultwarden%20Backup%20$1%20$time" \
              --message "$2"
          }

          on_failure() {
            echo "Sending failure email"
            send_notification "Failure" "$(cat <<EOF
          Time: $(date +"%Y-%m-%d %H:%M:%S")
          Error: line $LINENO: $BASH_COMMAND failed
          EOF
          )"
          }
          trap on_failure ERR

          tmp=$(mktemp -d)
          cleanup() {
            rm -rf "$tmp"
          }
          trap cleanup EXIT
          cd "$tmp"

          tar -cjf - -C "${backupDir}" . | age -R ${publicKey} -o "$time"

          hash=$(sha256sum "$time")
          echo "$hash" > "$time-sha256"

          archive_dir="/var/backup/vaultwarden-archive"

          # Archive locally
          mkdir -p "$archive_dir"
          cp "$time" "$archive_dir"
          cp "$time-sha256" "$archive_dir"

          # Because rclone has writes refresh client keys to it's configuration
          # we have to maintain a writeable copy of the config. When we detect
          # that the agenix config has been changed we replace it.
          state_dir="/var/lib/vaultwarden-cloud-backup"
          if ! cmp -s "$state_dir/rcloneConfigOriginal" "${rcloneConfig.path}"; then
            # If they have changed replace the writeable config with the agenix one
            install -m660 "${rcloneConfig.path}" "$state_dir/rcloneConfig"
          fi
          install -m660 "${rcloneConfig.path}" "$state_dir/rcloneConfigOriginal"

          rclone --config "$state_dir/rcloneConfig" copy . remote:backups/vaultwarden

          send_notification "Success" "$(cat <<EOF
          Timestamp: $time ($(date -d @"$time" +"%Y-%m-%d %H:%M:%S"))
          Hash: $(echo "$hash" | cut -d ' ' -f 1)
          Size: $(stat -c%s "$time" | numfmt --to=iec-i --suffix=B --format="%.1f")
          EOF
          )"

        '';
      };
    in
    {
      unitConfig = {
        Description = "Vaultwarden cloud backup";
        After = [ "backup-vaultwarden.service" "network-online.target" ];
        Requires = [ "backup-vaultwarden.service" ];
        Wants = [ "network-online.target" ];
      };

      serviceConfig = {
        EnvironmentFile = [ vaultwardenSMTPVars.path ];
        Type = "oneshot";
        ExecStart = getExe cloudBackupScript;
        User = "vaultwarden";
        Group = "vaultwarden";
        StateDirectory = "vaultwarden-cloud-backup";
      };

      wantedBy = [ "backup-vaultwarden.service" ];
    };

  services.caddy.virtualHosts = {
    # Unfortunately the bitwarden app does not support TLS client authentication
    # https://github.com/bitwarden/mobile/issues/582
    # https://github.com/bitwarden/mobile/pull/2629
    "vaultwarden.${fqDomain}".extraConfig = ''
      import lan_only
      reverse_proxy http://127.0.0.1:${toString cfg.port} {
        # Send the true remote IP to Rocket, so that Vaultwarden can put this
        # in the log
        header_up X-Real-IP {remote_host}
      }
    '';
  };

  persistence.directories = [
    {
      directory = "/var/lib/bitwarden_rs";
      user = "vaultwarden";
      group = "vaultwarden";
      mode = "770";
    }
    {
      # Just stores rclone config files
      directory = "/var/lib/vaultwarden-cloud-backup";
      user = "vaultwarden";
      group = "vaultwarden";
      mode = "770";
    }
    {
      # Stores the latest vault backup
      directory = "/var/backup/vaultwarden";
      user = "vaultwarden";
      group = "vaultwarden";
      mode = "770";
    }
    {
      # Stores an archive of all backups
      directory = "/var/backup/vaultwarden-archive";
      user = "vaultwarden";
      # WARN: Allows syncthing user service to share folder. Can probably
      # change this once I setup system syncthing service and sync with that
      # instead
      group = "users";
      mode = "770";
    }
  ];

  virtualisation.vmVariant = {
    systemd.services.vaultwarden-cloud-backup.enable = mkVMOverride false;
    networking.firewall.allowedTCPPorts = [ cfg.port ];

    services.vaultwarden = {
      environmentFile = mkVMOverride null;
      config.DOMAIN = mkVMOverride "http://127.0.0.1";
      config.ROCKET_ADDRESS = "0.0.0.0";
    };
  };
}
