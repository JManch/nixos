{
  ns,
  lib,
  config,
  inputs,
  ...
}:
let
  inherit (lib) mkIf singleton;
  inherit (config.${ns}.services) caddy;
  inherit (caddy) allowAddresses trustedAddresses;
  inherit (inputs.nix-resources.secrets) fqDomain;
  inherit (config.${ns}.device) vpnNamespace;
  cfg = config.${ns}.services.slskd;
in
mkIf cfg.enable {
  assertions = lib.${ns}.asserts [
    caddy.enable
    "Slskd requires Caddy to be enabled"
  ];

  services.slskd = {
    enable = true;
    environmentFile = config.age.secrets.slskdVars.path;
    openFirewall = false;
    settings = {
      web.port = cfg.port;
    };
  };

  systemd.services.slskd.vpnConfinement = {
    inherit vpnNamespace;
    enable = true;
  };

  vpnNamespaces.${vpnNamespace}.portMappings = singleton {
    from = cfg.port;
    to = cfg.port;
  };

  services.caddy.virtualHosts."slskd.${fqDomain}".extraConfig = ''
    ${allowAddresses trustedAddresses}
    reverse_proxy http://${config.vpnNamespaces.${vpnNamespace}.namespaceAddress}:${toString cfg.port}
  '';

  persistence.directories = singleton {
    directory = "/var/lib/slskd";
    user = "slskd";
    group = "slskd";
    mode = "0755";
  };
}
