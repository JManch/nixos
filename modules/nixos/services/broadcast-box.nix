{ lib, config, inputs, ... }:
let
  inherit (lib) mkIf mkForce optional genAttrs;
  inherit (inputs.nix-resources.secrets) fqDomain;
  cfg = config.modules.services.broadcast-box;
in
{
  imports = [
    inputs.broadcast-box.nixosModules.default
  ];

  services.broadcast-box = {
    enable = true;
    http.port = cfg.port;
    udpMux.port = cfg.udpMuxPort;
    # This breaks local streaming without hairpin NAT so hairpin NAT is needed
    # for streaming from local network when proxying
    nat.autoConfigure = cfg.proxy;
    statusAPI = !cfg.proxy;
  };

  systemd.services.broadcast-box.wantedBy = mkForce (
    optional cfg.autoStart "multi-user.target"
  );

  networking.firewall.interfaces = mkIf (!cfg.proxy) (genAttrs cfg.interfaces (_: {
    allowedTCPPorts = [ cfg.port ];
    allowedUDPPorts = [ cfg.udpMuxPort ];
  }));

  modules.system.networking.publicPorts = [ cfg.udpMuxPort ];
  networking.firewall.allowedUDPPorts = mkIf cfg.proxy [ cfg.udpMuxPort ];

  services.caddy.virtualHosts = mkIf cfg.proxy {
    "stream.${fqDomain}".extraConfig = ''
      reverse_proxy http://127.0.0.1:${toString cfg.port}
    '';
  };
}
