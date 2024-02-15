{ lib
, pkgs
, config
, ...
}:
let
  cfg = config.modules.services.broadcast-box;
in
lib.mkIf cfg.enable
{
  environment.systemPackages = [ pkgs.broadcast-box ];

  services.broadcast-box = {
    enable = true;
    http.port = 8080;
    udpMux.port = 3000;
    openFirewall = true;
  };

  networking.firewall.interfaces.wg-discord = {
    allowedTCPPorts = [ 8080 ];
    allowedUDPPorts = [ 3000 ];
  };
}
