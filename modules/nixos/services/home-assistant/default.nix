{
  lib,
  pkgs,
  config,
  inputs,
  hostname,
  selfPkgs,
  ...
}:
let
  inherit (lib)
    mkIf
    mkForce
    mkOption
    mkEnableOption
    types
    optional
    optionalString
    optionalAttrs
    utils
    getExe'
    mkVMOverride
    concatStringsSep
    escapeShellArg
    singleton
    attrNames
    ;
  inherit (config.modules.services) frigate mosquitto caddy;
  inherit (inputs.nix-resources.secrets) fqDomain;
  inherit (config.age.secrets) mqttHassPassword;
  inherit (caddy) trustedAddresses;
  inherit (secrets.general) people;
  cfg = config.modules.services.hass;
  secrets = inputs.nix-resources.secrets.hass { inherit lib config; };
  cameras = attrNames config.services.frigate.settings.cameras;
in
{
  imports = (utils.scanPaths ./.) ++ [ inputs.nix-resources.nixosModules.home-assistant ];

  options.modules.services.hass = {
    enable = mkEnableOption "Home Assistant";

    enableInternal = mkOption {
      type = types.bool;
      default = false;
      internal = true;
    };

    port = mkOption {
      type = types.port;
      default = 8123;
    };

    ceilingLightRooms = mkOption {
      type = types.listOf types.attrs;
      internal = true;
      readOnly = true;
      default = [
        {
          room = "joshua_room";
          light = "joshua_bulb_ceiling";
        }
        {
          room = "lounge";
          light = "lounge_spot_ceiling_1";
        }
        {
          room = "study";
          light = "study_spot_ceiling_1";
        }
        {
          room = "${people.person2}_room";
          light = "${people.person2}_spot_ceiling_1";
        }
      ];
      description = "Rooms with smart ceiling lights that should not be switched off";
    };
  };

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
        "isal" # https://www.home-assistant.io/integrations/isal
        "local_todo"
        "local_calendar"
        "generic_thermostat"
        "generic_hygrostat"
        "mold_indicator"
        "webostv"
        "powerwall"
        "co2signal"
        "forecast_solar"
        "husqvarna_automower"
        "roborock"
      ] ++ optional mosquitto.enable "mqtt";

      customComponents =
        [
          (pkgs.home-assistant-custom-components.miele.overrideAttrs {
            src = pkgs.fetchFromGitHub {
              owner = "astrandb";
              repo = "miele";
              rev = "refs/tags/v2024.8.1";
              hash = "sha256-XwaOQJvosCUXMZYrKX7sMWJIrMx36RhuVYUq163vvNg=";
            };
          })
          (pkgs.home-assistant-custom-components.waste_collection_schedule.overrideAttrs {
            src = pkgs.fetchFromGitHub {
              owner = "mampfes";
              repo = "hacs_waste_collection_schedule";
              rev = "refs/tags/2.0.1";
              hash = "sha256-nStfENwlPXPEvK13e8kUpPav6ul6XQO/rViHRHlZpKI=";
            };
          })
          pkgs.home-assistant-custom-components.adaptive_lighting
          selfPkgs.heatmiser
          selfPkgs.thermal-comfort
          selfPkgs.daikin-onecta
        ]
        ++ optional frigate.enable (
          pkgs.home-assistant-custom-components.frigate.overrideAttrs {
            src = pkgs.fetchFromGitHub {
              owner = "blakeblackshear";
              repo = "frigate-hass-integration";
              rev = "v5.3.0";
              hash = "sha256-0eTEgRDgm4+Om2uqrt24Gj7dSdA6OJs/0oi5J5SHOyI=";
            };
          }
        );

      configWritable = false;
      config = {
        # WARN: default_config enables zeroconf which runs an mDNS server. It
        # can't be disabled because several integrations depend on zeroconf.
        default_config = { };
        frontend = { };

        # Setting time zone in configuration.yaml makes it impossible to change
        # zone settings in the UI
        homeassistant.time_zone = null;

        recorder = {
          # We use postgresql instead of the default sqlite because it has better performance
          db_url = "postgresql://@/hass";

          # Spammy entities that produce useless data should be excluded from
          # the recorder. Note that recorder data is deleted after 10 days
          # (long-term data is managed seperately). This postgresql command is
          # useful for finding entities taking up db space. Run `\c hass` in
          # pgsql then:
          # SELECT
          #   states_meta.entity_id, states.metadata_id,
          #   COUNT(*) AS cnt
          # FROM states
          # LEFT JOIN states_meta ON states.metadata_id = states_meta.metadata_id
          # GROUP BY
          #   states_meta.entity_id, states.metadata_id
          # ORDER BY
          #   cnt DESC;
          #
          exclude = {
            entities = [ "sun.sun" ] ++ (map (camera: "binary_sensor.${camera}_motion") cameras);
            entity_globs = [
              "sensor.sun*"
              "switch.adaptive_lighting_*"
              "image.roborock_s6_maxv_*"
            ];
          };
        };

        http = {
          server_port = cfg.port;
          ip_ban_enabled = true;
          login_attempts_threshold = 3;
          use_x_forwarded_for = true;
          trusted_proxies = [
            "127.0.0.1"
            "::1"
          ];
        };

        camera = [
          {
            platform = "local_file";
            file_path = "/var/lib/hass/media/lounge_floorplan.png";
            name = "Lounge Floorplan";
          }
          {
            platform = "local_file";
            file_path = "/var/lib/hass/media/study_floorplan.png";
            name = "Study Floorplan";
          }
          {
            platform = "local_file";
            file_path = "/var/lib/hass/media/${people.person3}_room_floorplan.png";
            name = "${utils.upperFirstChar people.person3} Room Floorplan";
          }
        ];

        lovelace.resources = [
          {
            type = "js";
            url = "/local/thermal_comfort_icons.js";
          }
          {
            type = "js";
            url = "/local/formulaone-card/formulaone-card.js";
          }
          (optionalAttrs frigate.enable {
            url = "/local/frigate-hass-card/frigate-hass-card.js";
            type = "module";
          })
        ];
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
        inherit (selfPkgs)
          frigate-hass-card
          frigate-blueprint
          thermal-comfort-icons
          formulaone-card
          ;

        # Removing existing symbolic links so that packages will uninstall if
        # they're removed from config
        removeExistingLinks =
          subdir: # bash
          ''
            readarray -d "" links < <(find "${configDir}/${subdir}" -maxdepth 1 -type l -print0)
              for link in "''${links[@]}"; do
                if [[ "$(readlink "$link")" =~ ^${escapeShellArg builtins.storeDir} ]]; then
                  rm "$link"
                fi
              done
          '';
      in
      # bash
      ''
        mkdir -p "${configDir}/www"
        ${removeExistingLinks "www"}
        [[ -d ${configDir}/blueprints/automation/SgtBatten ]] && rm -rf "${configDir}/blueprints/automation/SgtBatten"
        ln -fsn "${thermal-comfort-icons}" "${configDir}/www/thermal_comfort_icons.js"
        ln -fsn "${formulaone-card}/formulaone-card" "${configDir}/www"

        ${optionalString frigate.enable # bash
          ''
            ln -fsn "${frigate-hass-card}/frigate-hass-card" "${configDir}/www"

            # For reasons I don't understand, blueprints will not work if they
            # are in a symlinked directory. The blueprint file has to be
            # symlinked directly.
            mkdir -p "${configDir}/blueprints/automation/SgtBatten"
            ln -fsn "${frigate-blueprint}/frigate_notifications.yaml" "${configDir}/blueprints/automation/SgtBatten/frigate_notifications.yaml"
          ''
        }
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
      ensureUsers = singleton {
        name = "hass";
        ensureDBOwnership = true;
      };

      # Version 15 enabled checkout logging by default which is quite verbose.
      # It's useful for debugging performance problems though this is unlikely
      # with my simple deployment.
      # https://git.postgresql.org/gitweb/?p=postgresql.git;a=commit;h=64da07c41a8c0a680460cdafc79093736332b6cf
      settings.log_checkpoints = false;
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

    # WARN: When upgrading postgresql to a new major version, make sure to use
    # the pq_dump and pq_restore binaries from the version you're upgrading to. 

    # Postgresql stateVersion upgrade steps:
    # - Stop home-assistant service
    # - nix shell n#postgresql-<new-version>
    # - sudo -i -u postgres; pg_dump -C -Fc hass | cat > /var/backup/postgresql/hass-migration-<version>.sql
    # - Stop postgresql.service
    # - Move /persist/var/lib/postgresql to /persist/var/lib/postgresql-<version> as a backup
    # - In Nix configuration, disable the home-assistant target below and upgrade the stateVersion
    # - rebuild-boot the host then reboot
    # - sudo -i -u postgres; pg_restore -U postgres --dbname postgres --clean --create /var/backup/...
    # - Re-enable the home-assistant target then rebuild-switch

    # Set this to false to prevent home-assistant from starting on the boot
    # after the database has been updated and the old dump needs to be restored
    systemd.targets.home-assistant.enable = true;

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

          postRestoreScript = # bash
            ''
              sudo -u postgres ${pg_restore} -U postgres --dbname postgres --clean --create ${backup}
            '';
        };
    };

    systemd.services.restic-backups-hass = {
      requires = [ "postgresqlBackup-hass.service" ];
      after = [ "postgresqlBackup-hass.service" ];
    };

    # We respond with a 404 instead of a 403 here because the iPhone home
    # assistant app completely resets and requires going through the onboarding
    # process if it receives a HTTP status code between 401 and 403. This is
    # frustrating because if the automatic VPN on an iPhone fails to connect at
    # at any point, the app resets.
    # https://github.com/home-assistant/iOS/issues/2824
    # https://github.com/home-assistant/iOS/blob/4770757f42da86eaadc949c3a2e97925f6a73ce8/Sources/Shared/API/Authentication/TokenManager.swift#L149
    services.caddy.virtualHosts."home.${fqDomain}".extraConfig = ''
      @block {
        not remote_ip ${concatStringsSep " " trustedAddresses}
      }
      respond @block "Access denied" 404 {
        close
      }
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
