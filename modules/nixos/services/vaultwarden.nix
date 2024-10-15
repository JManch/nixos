{
  ns,
  lib,
  pkgs,
  config,
  inputs,
  ...
}:
let
  inherit (lib)
    mkIf
    getExe
    getExe'
    mkForce
    mkVMOverride
    optional
    mkMerge
    ;
  inherit (config.${ns}.system.virtualisation) vmVariant;
  inherit (inputs.nix-resources.secrets) fqDomain;
  inherit (caddy) allowAddresses trustedAddresses;
  inherit (config.${ns}.services) caddy fail2ban;
  inherit (config.age.secrets)
    rcloneConfig
    vaultwardenVars
    vaultwardenSMTPVars
    vaultwardenPublicBackupKey
    healthCheckVaultwarden
    ;
  cfg = config.${ns}.services.vaultwarden;

  restoreScript = pkgs.writeShellApplication {
    name = "vaultwarden-restore-backup";
    runtimeInputs = with pkgs; [
      coreutils
      age
      bzip2
      gnutar
      systemd
    ];
    text = # bash
      ''
        if [ "$#" -ne 2 ]; then
          echo "Usage: vaultwarden-restore-backup <backup> <encrypted_private_key>"
          exit 1
        fi

        if [ "$(id -u)" != "0" ]; then
           echo "This script must be run as root" >&2
           exit 1
        fi

        echo "Tip: if you've restored from the Restic backup you can use the backup at /var/backup/vaultwarden-archive/latest";
        echo "Be careful to ensure that it's the latest backup because Restic backups do not run as frequently";

        backup=$1
        key=$2
        vault="/var/lib/bitwarden_rs"

        if [ ! -d "$vault" ]; then
          echo "Error: The vaultwarden state directory $vault does not exist" >&2
          exit 1
        fi

        if [ ! -e "$backup" ]; then
          echo "Error: $backup file does not exist" >&2
          exit 1
        fi

        if [ ! -e "$key" ]; then
          echo "Error: $key file does not exist" >&2
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
mkIf cfg.enable {
  assertions = lib.${ns}.asserts [
    caddy.enable
    "Vaultwarden requires Caddy to be enabled"
    fail2ban.enable
    "Vaultwarden requires Fail2ban to be enabled"
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
      # WARN: Vaultwarden exposes icons under /icons so login domains in the
      # vault are exposed to anyone who can access the server. Since we limit
      # vaultwarden exposure to LAN this is ok.

      # If an icon is not loading it may be due to a previously failed attempt
      # to fetch the icon. Vaultwarden creates a .miss file in the icon cache
      # which has to be manually deleted. Remember to also clear browser cache
      # when refreshing the page (CTRL+F5).
      ICON_BLACKLIST_NON_GLOBAL_IPS = false;
    };
  };

  # Upstream has good systemd hardening
  systemd.services.vaultwarden.serviceConfig = {
    EnvironmentFile =
      (optional (!vmVariant) vaultwardenSMTPVars.path)
      ++ (optional (!cfg.adminInterface) (
        pkgs.writeText "vaultwarden-disable-admin" ''
          ADMIN_TOKEN=""
        ''
      ));
  };

  # Run backup twice a day
  systemd.timers.backup-vaultwarden.timerConfig.OnCalendar = "08,20:00";
  systemd.services.backup-vaultwarden.wantedBy = mkForce [ ];

  adminPackages = [ restoreScript ];

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
          shoutrrr
        ];
        text = # bash
          ''
            set -o errtrace
            umask 0077
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
            for file in "$archive_dir"/latest*; do
              if [ -e "$file" ]; then
                mv "$file" "''${file/latest/last}"
              fi
            done
            cp "$time" "$archive_dir/latest"
            cp "$time-sha256" "$archive_dir/latest-sha256"

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
        After = [
          "backup-vaultwarden.service"
          "network-online.target"
        ];
        Requires = [ "backup-vaultwarden.service" ];
        Wants = [ "network-online.target" ];
      };

      serviceConfig = {
        EnvironmentFile = [ vaultwardenSMTPVars.path ];
        Type = "oneshot";
        ExecStart = getExe cloudBackupScript;
        ExecStartPost = "${getExe' pkgs.bash "sh"} -c '${getExe pkgs.curl} -s \"$(<${healthCheckVaultwarden.path})\"'";
        User = "vaultwarden";
        Group = "vaultwarden";
        StateDirectory = "vaultwarden-cloud-backup";
        # WARN: I've noticed that as the number of remote backup files grows,
        # rclone backups slow down significantly because it downloads all
        # remote files before every backup. I've seen it take 30 mins when the
        # remote folder grows large enough. The timeout should workaround this
        # by failing the service and notifying us when the rclone process is
        # taking too long suggesting the remote dir has grown too big. When
        # this happens rename the existing remote backup dir and replace it
        # with an empty one.
        TimeoutStartSec = 120;
      };

      wantedBy = [ "backup-vaultwarden.service" ];
    };

  services.caddy.virtualHosts = {
    # Unfortunately the bitwarden app does not support TLS client authentication
    # https://github.com/bitwarden/mobile/issues/582
    # https://github.com/bitwarden/mobile/pull/2629
    "vaultwarden.${fqDomain}".extraConfig = ''
      ${allowAddresses trustedAddresses}
      reverse_proxy http://127.0.0.1:${toString cfg.port} {
        # Send the true remote IP to Rocket, so that Vaultwarden can put this
        # in the log
        header_up X-Real-IP {remote_host}
      }
    '';
  };

  backups.vaultwarden = {
    paths = [ "/var/backup/vaultwarden-archive" ];
    restore.pathOwnership = {
      "/var/backup/vaultwarden-archive" = {
        user = "vaultwarden";
        group = "vaultwarden";
      };
    };
  };

  services.fail2ban.jails =
    let
      mkJail = name: failregex: {
        ${name} = {
          enabled = true;

          settings = {
            port = "${toString cfg.port},http,https";
            backend = "systemd";
          };

          filter.Definition = {
            inherit failregex;
            ignoreregex = "";
            journalmatch = "_SYSTEMD_UNIT=vaultwarden.service";
          };
        };
      };
    in
    mkMerge [
      (mkJail "vaultwarden-login" ''^.*Username or password is incorrect\. Try again\. IP: <ADDR>\..*$'')
      (mkJail "vaultwarden-2fa" ''^.*Invalid TOTP code.*IP: <ADDR>.*$'')
      (mkJail "vaultwarden-admin" ''^.*Invalid admin token\. IP: <ADDR>.*$'')
    ];

  persistence.directories = [
    {
      # WARN: This directory will change to /var/lib/vaultwarden in
      # stateVersion 24.11
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
      # Stores last two compressed backups
      directory = "/var/backup/vaultwarden-archive";
      user = "vaultwarden";
      group = "vaultwarden";
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
