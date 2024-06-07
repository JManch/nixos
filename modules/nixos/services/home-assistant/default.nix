{ lib
, pkgs
, config
, inputs
, outputs
, hostname
, ...
}:
let
  inherit (lib)
    mkIf
    mkForce
    optional
    optionalString
    optionalAttrs
    utils
    getExe'
    mkVMOverride
    mapAttrsToList
    escapeShellArg;
  inherit (config.modules.services) frigate mosquitto caddy;
  inherit (inputs.nix-resources.secrets) fqDomain;
  inherit (config.age.secrets) mqttHassPassword;
  inherit (secretCfg) devices;
  cfg = config.modules.services.hass;
  secretCfg = inputs.nix-resources.secrets.hass { inherit lib config; };
in
{
  imports = utils.scanPaths ./.;

  config = mkIf cfg.enable {
    assertions = utils.asserts [
      (hostname == "homelab")
      "Home Assistant is only intended to work on host 'homelab'"
      caddy.enable
      "Home Assistant requires Caddy to be enabled"
    ];

    modules.services.hass.enableInternal = true;

    services.home-assistant = {
      enable = true;
      openFirewall = false;

      package = pkgs.home-assistant.override {
        extraPackages = ps: [
          # For postgres support
          ps.psycopg2
        ];
      };

      extraComponents = [
        "sun"
        "radio_browser"
        "google_translate"
        "met" # weather
        "mobile_app"
        "profiler"
        "generic_thermostat"
        "generic_hygrostat"
        "mold_indicator"
        "hue"
        "webostv"
        "powerwall"
        "co2signal"
        "forecast_solar"
        "husqvarna_automower"
        "roborock"
      ] ++ optional mosquitto.enable "mqtt";

      customComponents = [
        pkgs.home-assistant-custom-components.miele
        (pkgs.home-assistant-custom-components.adaptive_lighting.overrideAttrs (oldAttrs: rec {
          version = "1.22.0";
          src = pkgs.fetchFromGitHub {
            owner = "basnijholt";
            repo = "adaptive-lighting";
            rev = version;
            hash = "sha256-k5pCgPM5xjVfWjOcr0UDFzYl/8z7yUwgYdBmC3+2F5k=";
          };
        }))
        outputs.packages.${pkgs.system}.heatmiser
        outputs.packages.${pkgs.system}.thermal-comfort
      ] ++ optional frigate.enable pkgs.home-assistant-custom-components.frigate;

      configWritable = false;
      config = {
        # WARN: default_config enables zeroconf which runs an mDNS server. It
        # can't be disabled because several integrations depend on zeroconf.
        default_config = { };
        frontend = { };

        # Setting time zone in configuration.yaml makes it impossible to change
        # zone settings in the UI
        homeassistant.time_zone = null;

        # We use postgresql instead of the default sqlite because it has better performance
        recorder.db_url = "postgresql://@/hass";

        http = {
          server_port = cfg.port;
          ip_ban_enabled = true;
          login_attempts_threshold = 3;
          use_x_forwarded_for = true;
          trusted_proxies = [ "127.0.0.1" "::1" ];
        };

        camera = [{
          platform = "local_file";
          file_path = "/var/lib/hass/media/lounge_floorplan.png";
          name = "Lounge Floorplan";
        }];

        lovelace.resources = [
          {
            type = "js";
            url = "/local/thermal_comfort_icons.js";
          }
          (optionalAttrs frigate.enable {
            url = "/local/frigate-hass-card/frigate-hass-card.js";
            type = "module";
          })
        ];

        notify = [{
          platform = "group";
          name = "All Notify Devices";
          services = mapAttrsToList (name: _: { service = name; }) devices;
        }];
      };
    };

    # Home assistant module has good systemd hardening

    systemd.services.home-assistant = {
      serviceConfig = {
        # For some reason home-assistant attempts to automatically start zha when
        # it detects a zigbee device. It throws an error because we don't have the
        # zha component installed. Even though the systemd service has
        # DevicePolicy=closed, home assistant somehow still detects my zigbee
        # device. This fixes that.
        PrivateDevices = true;
      };

      # Many configuration changes can be reloaded in the UI rather than having
      # to fully restart home assistant
      reloadTriggers = mkForce [ ];
    };

    # Install frigate-hass-card
    systemd.services.home-assistant.preStart =
      let
        inherit (config.services.home-assistant) configDir;
        inherit (outputs.packages.${pkgs.system}) frigate-hass-card frigate-blueprint thermal-comfort-icons;

        # Removing existing symbolic links so that packages will uninstall if
        # they're removed from config
        removeExistingLinks = subdir: /*bash*/ ''
          readarray -d "" links < <(find "${configDir}/${subdir}" -maxdepth 1 -type l -print0)
            for link in "''${links[@]}"; do
              if [[ "$(readlink "$link")" =~ ^${escapeShellArg builtins.storeDir} ]]; then
                rm "$link"
              fi
            done
        '';
      in
        /*bash*/ ''

        mkdir -p "${configDir}/www"
        ${removeExistingLinks "www"}
        [[ -d ${configDir}/blueprints/automation/SgtBatten ]] && rm -rf "${configDir}/blueprints/automation/SgtBatten"
        ln -fsn "${thermal-comfort-icons}" "${configDir}/www/thermal_comfort_icons.js"

        ${optionalString frigate.enable /*bash*/ ''
          ln -fsn "${frigate-hass-card}/frigate-hass-card" "${configDir}/www"

          # For reasons I don't understand, blueprints will not work if they
          # are in a symlinked directory. The blueprint file has to be
          # symlinked directly.
          mkdir -p "${configDir}/blueprints/automation/SgtBatten"
          ln -fsn "${frigate-blueprint}/frigate_notifications.yaml" "${configDir}/blueprints/automation/SgtBatten/frigate_notifications.yaml"
        ''}

      '';

    modules.services.mosquitto.users = {
      hass = {
        acl = [ "readwrite #" ];
        hashedPasswordFile = mqttHassPassword.path;
      };
    };

    services.postgresql = {
      enable = true;
      ensureDatabases = [ "hass" ];
      ensureUsers = [{
        name = "hass";
        ensureDBOwnership = true;
      }];
    };

    systemd.services.postgresql.serviceConfig = utils.hardeningBaseline config {
      DynamicUser = false;
      PrivateUsers = false;
    };

    services.postgresqlBackup = {
      enable = true;
      location = "/var/backup/postgresql";
      databases = [ "hass" ];
      # -Fc enables restoring with pg_restore
      pgdumpOptions = "-C -Fc";
      # The c format is compressed by default
      compression = "none";
      startAt = [ ];
    };

    backups.hass = {
      paths = [
        "/var/lib/hass"
        "/var/backup/postgresql/hass.sql"
      ];
      exclude = [ "*.log*" ];

      restore =
        let
          pg_restore = getExe' config.services.postgresql.package "pg_restore";
          backup = "/var/backup/postgresql/hass.sql";
        in
        {
          preRestoreScript = ''
            sudo systemctl stop home-assistant
          '';

          postRestoreScript = /*bash*/ ''
            sudo -u postgres ${pg_restore} -U postgres --dbname postgres --clean --create ${backup}
          '';
        };
    };

    systemd.services.restic-backups-hass = {
      requires = [ "postgresqlBackup-hass.service" ];
      after = [ "postgresqlBackup-hass.service" ];
    };

    services.caddy.virtualHosts."home.${fqDomain}".extraConfig = ''
      import lan-only
      reverse_proxy http://127.0.0.1:${toString cfg.port}
    '';

    persistence.directories = [
      {
        directory = "/var/lib/hass";
        user = "hass";
        group = "hass";
        mode = "700";
      }
      {
        directory = "/var/lib/postgresql";
        user = "postgres";
        group = "postgres";
        mode = "750";
      }
      {
        directory = "/var/backup/postgresql";
        user = "postgres";
        group = "postgres";
        mode = "750";
      }
    ];

    virtualisation.vmVariant = {
      networking.firewall.allowedTCPPorts = [ cfg.port ];

      services.home-assistant.config.http = {
        trusted_proxies = mkVMOverride [ "0.0.0.0/0" ];
      };
    };
  };
}
