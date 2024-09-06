{
  ns,
  lib,
  config,
  inputs,
  ...
}:
let
  inherit (lib)
    mkIf
    mkForce
    optional
    genAttrs
    optionalString
    ;
  inherit (inputs.nix-resources.secrets) fqDomain;
  inherit (config.${ns}.services) caddy;
  inherit (caddy) allowAddresses trustedAddresses;
  cfg = config.${ns}.services.broadcast-box;
in
{
  imports = [ inputs.broadcast-box.nixosModules.default ];

  config = mkIf cfg.enable {
    assertions = lib.${ns}.asserts [
      (cfg.proxy -> caddy.enable)
      "Broadcast box proxy mode requires caddy to be enabled"
    ];

    services.broadcast-box = {
      enable = true;
      settings = {
        HTTP_ADDRESS = "${optionalString cfg.proxy "127.0.0.1"}:${toString cfg.port}";
        UDP_MUX_PORT = cfg.udpMuxPort;
      };
    };

    systemd.services.broadcast-box.wantedBy = mkForce (optional cfg.autoStart "multi-user.target");

    networking.firewall.interfaces = genAttrs cfg.interfaces (_: {
      allowedTCPPorts = optional (!cfg.proxy) cfg.port;
      allowedUDPPorts = [ cfg.udpMuxPort ];
    });

    networking.firewall.allowedUDPPorts = [ cfg.udpMuxPort ];

    services.caddy.virtualHosts = mkIf cfg.proxy {
      "stream.${fqDomain}".extraConfig = ''
        ${allowAddresses (trustedAddresses ++ cfg.allowedAddresses)}
        reverse_proxy http://127.0.0.1:${toString cfg.port}
      '';
    };
  };
}
