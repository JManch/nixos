{
  lib,
  cfg,
  config,
  inputs,
}:
let
  inherit (lib) ns singleton;
  inherit (inputs.nix-resources.secrets) fqDomain;
in
{
  requirements = [ "services.caddy" ];

  opts = with lib; {
    port = mkOption {
      type = types.port;
      default = 9000;
      description = "Port for the Mealie server to listen on";
    };
  };

  services.mealie = {
    enable = true;
    listenAddress = "127.0.0.1";
    port = cfg.port;
    settings = {
      BASE_URL = "https://mealie.${fqDomain}";
      LOG_LEVEL = "warning";
    };
  };

  systemd.services.mealie.serviceConfig = lib.${ns}.hardeningBaseline config {
    SystemCallFilter = [
      "@system-service"
      "~@privileged"
    ];
  };

  ns.services.caddy.virtualHosts.mealie.extraConfig = ''
    reverse_proxy http://127.0.0.1:${toString cfg.port}
  '';

  ns.persistence.directories = singleton {
    directory = "/var/lib/private/mealie";
    user = "nobody";
    group = "nogroup";
    mode = "0755";
  };
}
