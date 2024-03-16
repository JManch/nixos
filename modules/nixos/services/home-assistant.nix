{ lib
, pkgs
, config
, inputs
, outputs
, ...
}:
let
  inherit (lib) mkIf optional mkVMOverride;
  inherit (config.modules.services) frigate;
  inherit (inputs.nix-resources.secrets) fqDomain;
  cfg = config.modules.services.home-assistant;
  personal-hass-components = outputs.packages.${pkgs.system}.home-assistant-custom-components;
in
# NOTE: This is very WIP
mkIf cfg.enable
{
  services.home-assistant = {
    enable = true;
    openFirewall = false;

    package = (pkgs.home-assistant.override {
      # Needed for postgres support
      extraPackages = ps: [
        ps.psycopg2
      ];
    });

    configWritable = true;
    extraComponents = [
      "google_translate"
    ];
    customComponents = with pkgs.home-assistant-custom-components; [
      # TODO: Update these
      miele
      adaptive_lighting
    ] ++ optional frigate.enable personal-hass-components.frigate-hass-integration;

    config = {
      default_config = { };
      frontend = { };
      # We use postgresql instead of the default sqlite because it has better performance
      recorder.db_url = "postgresql://@/hass";

      http = {
        ip_ban_enabled = true;
        login_attempts_threshold = 3;
        use_x_forwarded_for = true;
        trusted_proxies = [ "127.0.0.1" "::1" ];
      };

      automation = { };
    };

    # TODO: Figure out a way to configure the lovelace dashboard. Not sure if I
    # want it be declarative or encrypted?
  };

  services.postgresql = {
    enable = true;
    ensureDatabases = [ "hass" ];
    ensureUsers = [{
      name = "hass";
      ensureDBOwnership = true;
    }];
  };

  services.caddy.virtualHosts."home.${fqDomain}".extraConfig = ''
    reverse_proxy http://127.0.0.1:8123
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
  ];

  virtualisation.vmVariant = {
    networking.firewall.allowedTCPPorts = [ 8123 ];

    services.home-assistant.config.http = {
      trusted_proxies = mkVMOverride [ "0.0.0.0/0" ];
    };
  };
}
