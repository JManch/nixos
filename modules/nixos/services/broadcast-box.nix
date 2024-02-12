{ lib
, pkgs
, config
, outputs
, ...
}:
let
  cfg = config.modules.services.broadcast-box;
in
lib.mkIf cfg.enable
{
  services.broadcast-box = {
    enable = true;
    package = outputs.packages.${pkgs.system}.broadcast-box;
    tcpPort = 8081;
    udpMuxPort = 3000;
    autoStart = false;
    openFirewall = false;
  };

  networking.firewall.interfaces.wg-discord = {
    allowedTCPPorts = [ 8081 ];
    allowedUDPPorts = [ 3000 ];
  };
}
