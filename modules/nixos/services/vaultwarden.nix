{ lib
, pkgs
, config
, inputs
, ...
}:
let
  inherit (lib) mkIf getExe mkForce;
  inherit (inputs.nix-resources.secrets) fqDomain vaultwardenSubdir;
  inherit (config.modules.services) caddy;
  inherit (config.age.secrets)
    rcloneConfig
    vaultwardenVars
    vaultwardenSMTPVars
    vaultwardenPublicBackupKey;
  cfg = config.modules.services.vaultwarden;
in
mkIf (cfg.enable && caddy.enable)
{
  # TODO: Test I can actually decrypt and restore backups
  # TODO: Configure protonmail to sort backup alerts

  services.vaultwarden = {
    enable = true;
    backupDir = "/var/backup/vaultwarden";
    environmentFile = vaultwardenVars.path;

    config = {
      # Reference: https://github.com/dani-garcia/vaultwarden/blob/1.30.5/.env.template
      DOMAIN = "https://bitwarden.${fqDomain}/${vaultwardenSubdir}";
      SIGNUPS_ALLOWED = false;
      INVITATIONS_ALLOWED = false;
      SHOW_PASSWORD_HINT = false;
      ROCKET_PORT = cfg.port;
    };
  };

  systemd.services.vaultwarden.serviceConfig = {
    EnvironmentFile = [ vaultwardenSMTPVars.path ];
  };

  # Run backup twice a day
  systemd.timers.backup-vaultwarden.timerConfig.OnCalendar = "08,20:00";
  systemd.services.backup-vaultwarden.wantedBy = mkForce [ ];

  systemd.services.vaultwarden-cloud-backup =
    let
      inherit (config.services.vaultwarden) backupDir;
      publicKey = vaultwardenPublicBackupKey.path;
      cloudBackupScript = pkgs.writeShellApplication {
        name = "vaultwarden-cloud-backup";
        runtimeInputs = with pkgs; [
          coreutils
          diffutils
          msmtp
          gnutar
          age
          rclone
        ];
        text = /*bash*/ ''

          set -o errtrace

          send_email() {
            recipient="JManch@protonmail.com"
            msmtp --host="$SMTP_HOST" \
                  --port="$SMTP_PORT" \
                  --auth=on \
                  --user="$SMTP_USERNAME" \
                  --passwordeval="echo $SMTP_PASSWORD" \
                  --tls=on \
                  --tls-starttls=on \
                  --from="$SMTP_FROM" \
                  "$recipient" <<EOF
          Subject: Vaultwarden Backup $1
          From: $SMTP_FROM
          To: $recipient

          $2
          EOF
          }

          on_failure() {
            echo "Sending failure email"
            send_email "Failure" "$(cat <<EOF
          Vaultwarden backup failed

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

          time=$(date +%s)
          tar -cf "$time.tar" -C "${backupDir}" .
          age -R ${publicKey} -o "$time" "$time.tar"
          rm -f "$time.tar"

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

          send_email "Success" "$(cat <<EOF
          Vaultwarden backed up successfully

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
        After = "backup-vaultwarden.service";
        Requires = "backup-vaultwarden.service";
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
    "bitwarden.${fqDomain}".extraConfig = ''
      import lan_only
      route {
        reverse_proxy /${vaultwardenSubdir}/* http://127.0.0.1:${toString cfg.port}
        handle /* {
          abort
        }
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
      group = "vaultwarden";
      mode = "770";
    }
  ];
}
