{ lib
, pkgs
, config
, inputs
, outputs
, hostname
, ...
} @ args:
let
  inherit (lib) mkIf optional utils mkVMOverride escapeShellArg;
  inherit (config.modules.services) frigate mosquitto caddy;
  inherit (inputs.nix-resources.secrets) fqDomain;
  cfg = config.modules.services.hass;
in
{
  imports = utils.scanPaths ./.;

  config = mkIf (cfg.enable && hostname == "homelab" && caddy.enable) {
    modules.services.hass.enableInternal = true;

    services.home-assistant = {
      enable = true;
      openFirewall = false;

      package = (pkgs.home-assistant.override {
        extraPackages = ps: [
          # For postgres support
          ps.psycopg2
        ];
      });

      extraComponents = [
        "sun"
        "radio_browser"
        "google_translate"
        "met" # weather
        "mobile_app"
        "profiler"
        "hue"
        "webostv"
        "powerwall"
        "co2signal"
        "forecast_solar"
        "husqvarna_automower"
      ] ++ optional mosquitto.enable "mqtt";

      customComponents = with pkgs.home-assistant-custom-components; [
        (miele.overrideAttrs (oldAttrs: rec {
          version = "2024.3.0";
          src = pkgs.fetchFromGitHub {
            owner = oldAttrs.owner;
            repo = oldAttrs.domain;
            rev = "refs/tags/v${version}";
            hash = "sha256-J9n4PFcd87L301B2YktrLcxp5Vu1HwDeCYnrMEJ0+TA=";
          };
        }))

        (adaptive_lighting.overrideAttrs (oldAttrs: rec {
          version = "1.20.0";
          src = pkgs.fetchFromGitHub {
            owner = "basnijholt";
            repo = "adaptive-lighting";
            rev = "refs/tags/${version}";
            hash = "sha256-4Emm7/UJvgU7gaPNiD/JJrMCDpmLuW3Me0sKwB9+KYI=";
          };
        }))

        (utils.flakePkgs args "graham33").heatmiser-for-home-assistant
      ] ++ optional frigate.enable pkgs.home-assistant-custom-components.frigate;

      configWritable = false;
      config = {
        default_config = { };
        frontend = { };

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

        lovelace.resources = mkIf frigate.enable [{
          url = "/local/frigate-hass-card/frigate-hass-card.js";
          type = "module";
        }];

        automation = { };
      };
    };

    # Home assistant module has good systemd hardening

    # Install frigate-hass-card
    systemd.services.home-assistant.preStart =
      let
        inherit (config.services.home-assistant) configDir;
      in
      mkIf frigate.enable /*bash*/ ''

      mkdir -p "${configDir}/www"

      # Removing existing symbolic links so that frigate-hass-card will
      # uninstall if it's removed from config
      readarray -d "" links < <(find "${configDir}/www" -maxdepth 1 -type l -print0)
        for link in "''${links[@]}"; do
          if [[ "$(readlink "$link")" =~ ^${escapeShellArg builtins.storeDir} ]]; then
            rm "$link"
          fi
        done

      ln -fsn "${outputs.packages.${pkgs.system}.frigate-hass-card}/frigate-hass-card" "${configDir}/www"

    '';

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

    services.caddy.virtualHosts = {
      # Because iPhones are terrible and don't accept my certs
      # (I don't this iPhone HA app supports certs anyway)
      "home.${fqDomain}".extraConfig = ''
        import lan_only
        reverse_proxy http://127.0.0.1:${toString cfg.port}
      '';

      "home-wan.${fqDomain}".extraConfig = ''
        tls {
          client_auth {
            mode require_and_verify
            trusted_ca_cert_file ${config.age.secrets.rootCA.path}
            trusted_leaf_cert_file ${config.age.secrets.homeCert.path}
          }
        }
        reverse_proxy http://127.0.0.1:${toString cfg.port}
      '';
    };

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
    ];

    virtualisation.vmVariant = {
      networking.firewall.allowedTCPPorts = [ cfg.port ];

      services.home-assistant.config.http = {
        trusted_proxies = mkVMOverride [ "0.0.0.0/0" ];
      };
    };
  };
}