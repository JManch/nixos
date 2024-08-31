{ lib, config, ... }:
let
  inherit (lib)
    mkIf
    utils
    genAttrs
    ;
  cfg = config.modules.services.avahi;
in
mkIf cfg.enable {
  assertions = utils.asserts [
    (cfg.interfaces != [ ])
    "Avahi interface list cannot be empty"
  ];

  services.avahi = {
    enable = true;
    openFirewall = false;
    allowInterfaces = cfg.interfaces;
    reflector = true;
    ipv4 = true;
    ipv6 = false;
    domainName = "local";
  };

  networking.firewall.interfaces = genAttrs cfg.interfaces (_: {
    allowedUDPPorts = [ 5353 ];
  });
}
