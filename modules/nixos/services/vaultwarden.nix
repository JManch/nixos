{
  lib,
  cfg,
  pkgs,
  config,
  inputs,
}:
let
  inherit (lib)
    ns
    mkForce
    getExe
    mkVMOverride
    optional
    mkMerge
    ;
  inherit (config.${ns}.system) virtualisation;
  inherit (inputs.nix-resources.secrets) fqDomain;
  inherit (config.age.secrets)
    vaultwardenVars
    vaultwardenSMTPVars
    vaultwardenPublicBackupKey
    ;

  restoreScript = pkgs.writeShellApplication {
    name = "vaultwarden-restore-backup";
    runtimeInputs = with pkgs; [
      coreutils
      age
      bzip2
      gnutar
      systemd
    ];
    text = ''
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
{
  requirements = [
    "services.caddy"
    "services.fail2ban"
  ];

  opts = with lib; {
    adminInterface = mkEnableOption "admin interface. Keep disabled and enable when needed.";

    port = mkOption {
      type = types.port;
      default = 8222;
    };

    extraAllowedAddresses = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = ''
        List of address to give access to Vaultwarden in addition to the
        trusted list.
      '';
    };
  };

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
  systemd.services.vaultwarden.serviceConfig.EnvironmentFile =
    (optional (!virtualisation.vmVariant) vaultwardenSMTPVars.path)
    ++ (optional (!cfg.adminInterface) (
      pkgs.writeText "vaultwarden-disable-admin" ''
        ADMIN_TOKEN=""
      ''
    ));

  # Run backup twice a day
  systemd.timers.backup-vaultwarden.timerConfig.OnCalendar = "08,20:00";
  systemd.services.backup-vaultwarden.wantedBy = mkForce [ ];

  systemd.services.backup-vaultwarden.serviceConfig.ExecStartPost = getExe (
    pkgs.writeShellApplication {
      name = "vaultwarden-prepare-cloud-backup";
      runtimeInputs = with pkgs; [
        coreutils
        gnutar
        bzip2
        age
      ];
      text = ''
        umask 0077
        time=$(date +%s)
        tmp=$(mktemp -d)
        cleanup() {
          rm -rf "$tmp"
        }
        trap cleanup EXIT
        cd "$tmp"

        tar -cjf - -C "${config.services.vaultwarden.backupDir}" . | age -R ${vaultwardenPublicBackupKey.path} -o "$time"
        hash=$(sha256sum "$time")
        echo "$hash" > "$time-sha256"

        # Archive locally
        archive_dir="/var/backup/vaultwarden-archive"
        mkdir -p "$archive_dir"
        for file in "$archive_dir"/latest*; do
          if [ -e "$file" ]; then
            mv "$file" "''${file/latest/last}"
          fi
        done
        cp "$time" "$archive_dir/latest"
        cp "$time-sha256" "$archive_dir/latest-sha256"

        # Prepare cloud upload folder
        cloud_upload_dir="/tmp/vaultwarden-cloud-upload"
        rm -rf "$cloud_upload_dir"
        mkdir -p "$cloud_upload_dir"
        mv ./* "$cloud_upload_dir"
      '';
    }
  );

  ns.adminPackages = [ restoreScript ];

  systemd.tmpfiles.rules = [
    # Upstream module creates the /var/backup/vaultwarden dir
    "d /var/backup/vaultwarden-archive 0700 vaultwarden vaultwarden - -"
  ];

  # Unfortunately the bitwarden app does not support TLS client authentication
  # https://github.com/bitwarden/mobile/issues/582
  # https://github.com/bitwarden/mobile/pull/2629
  ns.services.caddy.virtualHosts.vaultwarden = {
    inherit (cfg) extraAllowedAddresses;
    extraConfig = ''
      reverse_proxy http://127.0.0.1:${toString cfg.port} {
        # Send the true remote IP to Rocket, so that Vaultwarden can put this
        # in the log
        header_up X-Real-IP {remote_host}
      }
    '';
  };

  ns.backups = {
    vaultwarden-restic = {
      backend = "restic";
      paths = [ "/var/backup/vaultwarden-archive" ];
      timerConfig = null;
      notifications = {
        failure.config = {
          title = "Vaultwarden Restic Backup Failure";
          discord.enable = true;
          discord.var = "VAULTWARDEN";
        };
        healthCheck.enable = true;
      };

      restore.pathOwnership."/var/backup/vaultwarden-archive" = {
        user = "vaultwarden";
        group = "vaultwarden";
      };
    };

    vaultwarden-rclone = {
      backend = "rclone";
      paths = [ "/tmp/vaultwarden-cloud-upload" ];
      doNotModifyPaths = true;
      timerConfig = null;

      notifications = {
        failure.config = {
          title = "Vaultwarden Rclone Backup Failure";
          discord.enable = true;
          discord.var = "VAULTWARDEN";
        };

        success = {
          enable = true;
          config = {
            title = "Vaultwarden Rclone Backup Success";
            contentsScript =
              (pkgs.writeShellScript "vaultwarden-success-notification-contents" ''
                export PATH="${pkgs.coreutils}/bin:${pkgs.fd}/bin:$PATH"
                timestamp=$(fd --base-directory /tmp/vaultwarden-cloud-upload -E '*sha256')
                timestamp_file="/tmp/vaultwarden-cloud-upload/$timestamp"
                echo -e "Timestamp: $timestamp ($(date -d @"$timestamp" +"%Y-%m-%d %H:%M:%S"))\nHash: $(cut -d ' ' -f 1 "$timestamp_file-sha256")\nSize: $(stat -c%s "$timestamp_file" | numfmt --to=iec-i --suffix=B --format="%.1f")\n"
              '').outPath;
            discord.enable = true;
            discord.var = "VAULTWARDEN";
          };
        };

        healthCheck.enable = true;
      };

      backendOptions = {
        remote = "protondrive";
        mode = "copy";
        timeout = 120;
        remotePaths."/tmp/vaultwarden-cloud-upload" = "vaultwarden";
      };

      restore.pathOwnership."/tmp/vaultwarden-cloud-upload" = {
        user = "vaultwarden";
        group = "vaultwarden";
      };
    };
  };

  systemd.services."rclone-backups-vaultwarden-rclone" = {
    after = [ "backup-vaultwarden.service" ];
    requires = [ "backup-vaultwarden.service" ];
    wantedBy = [ "backup-vaultwarden.service" ];
  };

  systemd.services."restic-backups-vaultwarden-restic" = {
    after = [ "backup-vaultwarden.service" ];
    requires = [ "backup-vaultwarden.service" ];
    wantedBy = [ "backup-vaultwarden.service" ];
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

  ns.persistence.directories = [
    {
      # WARN: This directory will change to /var/lib/vaultwarden in
      # stateVersion 24.11
      directory = "/var/lib/bitwarden_rs";
      user = "vaultwarden";
      group = "vaultwarden";
      mode = "0700";
    }
    {
      # Just stores rclone config files
      directory = "/var/lib/vaultwarden-cloud-backup";
      user = "vaultwarden";
      group = "vaultwarden";
      mode = "0700";
    }
    {
      # Stores the latest vault backup
      directory = "/var/backup/vaultwarden";
      user = "vaultwarden";
      group = "vaultwarden";
      mode = "0700";
    }
    {
      # Stores last two compressed backups
      directory = "/var/backup/vaultwarden-archive";
      user = "vaultwarden";
      group = "vaultwarden";
      mode = "0700";
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
