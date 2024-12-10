{
  lib,
  config,
  inputs,
  ...
}:
let
  inherit (lib) ns mkIf singleton;
  inherit (inputs.nix-resources.secrets) fqDomain;
  inherit (config.${ns}.services) caddy;
  cfg = config.${ns}.services.mealie;
in
mkIf cfg.enable {
  assertions = lib.${ns}.asserts [
    caddy.enable
    "Mealie requires Caddy to be enabled"
  ];

  services.mealie = {
    enable = true;
    listenAddress = "127.0.0.1";
    port = cfg.port;
    settings = {
      BASE_URL = "https://mealie.${fqDomain}";
      LOG_LEVEL = "warning";
    };
  };

  users.users.mealie = {
    group = "mealie";
    isSystemUser = true;
  };
  users.groups.mealie = { };

  systemd.services.mealie.serviceConfig = lib.${ns}.hardeningBaseline config {
    User = "mealie";
    Group = "mealie";
  };

  ${ns}.services.caddy.virtualHosts.mealie.extraConfig = ''
    reverse_proxy http://127.0.0.1:${toString cfg.port}
  '';

  persistence.directories = singleton {
    directory = "/var/lib/private/mealie";
    user = "mealie";
    group = "mealie";
    mode = "0755";
  };
}
