{
  lib,
  cfg,
  pkgs,
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
    package =
      (import (fetchTree "github:NixOS/nixpkgs/c6a788f552b7b7af703b1a29802a7233c0067908") {
        inherit (pkgs) system;
      }).mealie;
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
    user = "mealie";
    group = "mealie";
    mode = "0755";
  };
}
