{ lib, config, ... }:
let
  inherit (lib) mkIf mkForce optional;
  cfg = config.modules.services.broadcast-box;
in
mkIf cfg.enable
{
  services.broadcast-box = {
    enable = true;
    http.port = 8080;
    udpMux.port = 3000;
    openFirewall = true;
  };

  systemd.services.broadcast-box.wantedBy = mkForce (
    optional cfg.autoStart [ "multi-user.target" ]
  );

  networking.firewall.interfaces.wg-discord = {
    allowedTCPPorts = [ 8080 ];
    allowedUDPPorts = [ 3000 ];
  };
}
