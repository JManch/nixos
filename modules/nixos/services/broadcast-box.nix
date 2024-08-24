{
  lib,
  config,
  inputs,
  ...
}:
let
  inherit (lib)
    mkIf
    utils
    mkForce
    optional
    genAttrs
    optionalString
    ;
  inherit (inputs.nix-resources.secrets) fqDomain;
  inherit (config.modules.services) caddy;
  inherit (caddy) allowAddresses trustedAddresses;
  cfg = config.modules.services.broadcast-box;
in
{
  imports = [ inputs.broadcast-box.nixosModules.default ];

  config = mkIf cfg.enable {
    assertions = utils.asserts [
      (cfg.proxy -> caddy.enable)
      "Broadcast box proxy mode requires caddy to be enabled"
    ];

    services.broadcast-box = {
      enable = true;
      settings = {
        HTTP_ADDRESS = "${optionalString cfg.proxy "127.0.0.1"}:${toString cfg.port}";
        UDP_MUX_PORT = cfg.udpMuxPort;
        # This breaks local streaming without hairpin NAT so hairpin NAT is needed
        # for streaming from local network when proxying
        INCLUDE_PUBLIC_IP_IN_NAT_1_TO_1_IP = cfg.proxy;
        DISABLE_STATUS = true;
      };
    };

    systemd.services.broadcast-box.wantedBy = mkForce (optional cfg.autoStart "multi-user.target");

    networking.firewall.interfaces = mkIf (!cfg.proxy) (
      genAttrs cfg.interfaces (_: {
        allowedTCPPorts = [ cfg.port ];
        allowedUDPPorts = [ cfg.udpMuxPort ];
      })
    );

    modules.system.networking.publicPorts = [ cfg.udpMuxPort ];
    networking.firewall.allowedUDPPorts = mkIf cfg.proxy [ cfg.udpMuxPort ];

    services.caddy.virtualHosts = mkIf cfg.proxy {
      "stream.${fqDomain}".extraConfig = ''
        ${allowAddresses (trustedAddresses ++ cfg.allowedAddresses)}
        reverse_proxy http://127.0.0.1:${toString cfg.port}
      '';
    };
  };
}
