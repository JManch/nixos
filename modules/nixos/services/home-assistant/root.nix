{
  lib,
  cfg,
  pkgs,
  config,
  inputs,
  sources,
  hostname,
  selfPkgs,
}:
let
  inherit (lib)
    ns
    mkIf
    mkForce
    mkOption
    mkEnableOption
    types
    optional
    optionalString
    optionalAttrs
    getExe'
    mkVMOverride
    escapeShellArg
    singleton
    attrNames
    ;
  inherit (config.${ns}.services) frigate mosquitto;
  inherit (config.${ns}.core) device;
  inherit (config.age.secrets) everythingPresenceVars mqttHassPassword mqttFaikinPassword;
  cameras = attrNames config.services.frigate.settings.cameras;
in
{
  imports = [ inputs.nix-resources.nixosModules.home-assistant ];

  enableOpt = true;
  noChildren = true;

  opts = {
    everythingPresenceContainer = mkEnableOption "everything presence container";

    port = mkOption {
      type = types.port;
      default = 8123;
    };
  };

  requirements = [
    "services.caddy"
    "services.postgresql"
  ];

  asserts = [
    (hostname == "homelab")
    "Home Assistant is only intended to work on host 'homelab'"
  ];

  warnings = optional cfg.everythingPresenceContainer "Home Assistant Everything Presence container is enabled; it should only be used temporarily.";

  ns.services = {
    mosquitto = {
      users = {
        hass = {
          acl = [ "readwrite #" ];
          hashedPasswordFile = mqttHassPassword.path;
        };

        # Faikin doesn't support mqtt tls unfortunately. To mitigate this we
        # restrict acls and run on trusted LAN.
        # WARN: prefixapp and prefixhost need to be enabled in faikin settings
        faikin = {
          acl = [
            "readwrite Faikin/#"
            "readwrite homeassistant/climate/#"
          ];
          hashedPasswordFile = mqttFaikinPassword.path;
        };
      };

      tlsUsers = {
        shelly = {
          acl = [ "readwrite #" ];
          hashedPasswordFile = config.age.secrets.mqttShellyPassword.path;
        };
      };
    };

    # We respond with a 404 instead of a 403 here because the iPhone home
    # assistant app completely resets and requires going through the onboarding
    # process if it receives a HTTP status code between 401 and 403. This is
    # frustrating because if the automatic VPN on an iPhone fails to connect at
    # at any point, the app resets.
    # https://github.com/home-assistant/iOS/issues/2824
    # https://github.com/home-assistant/iOS/blob/4770757f42da86eaadc949c3a2e97925f6a73ce8/Sources/Shared/API/Authentication/TokenManager.swift#L149

    # Edit: I no longer publically expose my reverse proxy so the above
    # workaround isn't needed as my firewall just drops the connection. Leaving
    # the note for future reference.
    caddy.virtualHosts.home.extraConfig = ''
      reverse_proxy http://127.0.0.1:${toString cfg.port}
    '';
  };

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
      "local_file"
      "local_todo"
      "local_calendar"
      "generic_thermostat"
      "generic_hygrostat"
      "mold_indicator"
      "history_stats"
      "webostv"
      "powerwall"
      "co2signal"
      "forecast_solar"
      "husqvarna_automower"
      "roborock"
      "unifi"
      "esphome"
      "miele"
    ] ++ optional mosquitto.enable "mqtt";

    customComponents =
      [
        (pkgs.home-assistant-custom-components.waste_collection_schedule.overrideAttrs {
          inherit (sources.hacs_waste_collection_schedule) version;
          src = sources.hacs_waste_collection_schedule;
        })
        (pkgs.home-assistant-custom-components.adaptive_lighting.overrideAttrs {
          inherit (sources.adaptive-lighting) version;
          src = sources.adaptive-lighting;
        })
        selfPkgs.heatmiser
        selfPkgs.thermal-comfort
        selfPkgs.daikin-onecta
      ]
      ++ optional frigate.enable (
        let
          hass-web-proxy-lib = pkgs.python313Packages.buildPythonPackage {
            pname = "hass-web-proxy-lib";
            version = "0-unstable-${sources.hass-web-proxy-lib.revision}";
            src = sources.hass-web-proxy-lib;
            pyproject = true;
            build-system = [
              pkgs.python313Packages.setuptools
              pkgs.python313Packages.poetry-core
            ];
          };
        in
        pkgs.home-assistant-custom-components.frigate.overridePythonAttrs {
          inherit (sources.frigate-hass-integration) version;
          src = sources.frigate-hass-integration;

          dependencies = [
            pkgs.python313Packages.pytz
            hass-web-proxy-lib
          ];
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
        # (long-term data is managed separately). This postgresql command is
        # useful for finding entities taking up db space. Run `\c hass` in
        # psql then:
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
          entities = [
            "sun.sun"
            "input_text.announcement_message"
          ] ++ (map (camera: "binary_sensor.${camera}_motion") cameras);
          entity_globs = [
            "sensor.sun*"
            "switch.adaptive_lighting_*"
            "image.roborock_s6_maxv_*"
            "input_text.*_announcement_response"
            "input_boolean.*_announcement_achnowledged"
            "sensor.*_faikin_liquid"
            "sensor.*_presence_*" # presence sensors spam A LOT
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

      lovelace.resources = [
        {
          type = "js";
          url = "/local/thermal_comfort_icons.js";
        }
        (optionalAttrs frigate.enable {
          url = "/local/advanced-camera-card/advanced-camera-card.js";
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
    # to fully restart home assistant. Lovelace config can be reloaded by
    # pressing "refresh" in the top right of the dashboard.
    reloadTriggers = mkForce [ ];
  };

  systemd.services.home-assistant.preStart =
    let
      inherit (config.services.home-assistant) configDir;
      inherit (selfPkgs)
        advanced-camera-card
        frigate-blueprint
        thermal-comfort-icons
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

      ${optionalString frigate.enable # bash
        ''
          ln -fsn "${advanced-camera-card}/advanced-camera-card" "${configDir}/www"

          # For reasons I don't understand, blueprints will not work if they
          # are in a symlinked directory. The blueprint file has to be
          # symlinked directly.
          mkdir -p "${configDir}/blueprints/automation/SgtBatten"
          ln -fsn "${frigate-blueprint}/frigate_notifications.yaml" "${configDir}/blueprints/automation/SgtBatten/frigate_notifications.yaml"
        ''
      }
    '';

  services.postgresql = {
    ensureDatabases = [ "hass" ];
    ensureUsers = singleton {
      name = "hass";
      ensureDBOwnership = true;
    };
  };

  services.postgresqlBackup.databases = [ "hass" ];

  ns.backups.hass = {
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
        preRestoreScript = "sudo systemctl stop home-assistant";

        postRestoreScript = ''
          sudo -u postgres ${pg_restore} -U postgres --dbname postgres --clean --create ${backup}
        '';
      };
  };

  systemd.services.restic-backups-hass = {
    requires = [ "postgresqlBackup-hass.service" ];
    after = [ "postgresqlBackup-hass.service" ];
  };

  virtualisation.oci-containers.containers.everything-presence =
    mkIf cfg.everythingPresenceContainer
      {
        image = "everythingsmarthome/everything-presence-mmwave-configurator:latest";
        ports = [ "8099:8099" ];
        environment.HA_URL = "http://${device.address}:8123";
        environmentFiles = [ everythingPresenceVars.path ];
      };

  networking.firewall.allowedTCPPorts = mkIf cfg.everythingPresenceContainer [ 8099 ];
  networking.firewall.interfaces.podman0.allowedTCPPorts = mkIf cfg.everythingPresenceContainer [
    8123
  ];

  ns.persistence.directories = singleton {
    directory = "/var/lib/hass";
    user = "hass";
    group = "hass";
    mode = "0700";
  };

  virtualisation.vmVariant = {
    networking.firewall.allowedTCPPorts = [ cfg.port ];

    services.home-assistant.config.http = {
      trusted_proxies = mkVMOverride [ "0.0.0.0/0" ];
    };
  };
}
