{ lib, config, ... }:
let
  cfg = config.modules.services.wgnord;
in
lib.mkIf cfg.enable
{
  services.wgnord = {
    enable = true;
    tokenFile = config.age.secrets.nordToken.path;
    country = cfg.country;
    # TODO: Allow all IPs apart from 192.168.0.0/16 and 10.0.0.0/8. Using the
    # output from wireguard allowed IPs calculator does not work for some
    # reason. Probably need an iptables rule instead.
    template = ''
      [Interface]
      PrivateKey = PRIVKEY
      Address = 10.5.0.2/32
      MTU = 1350
      DNS = 103.86.96.100 103.86.99.100

      [Peer]
      PublicKey = SERVER_PUBKEY
      AllowedIPs = 0.0.0.0/0
      Endpoint = SERVER_IP:51820
      PersistentKeepalive = 25
    '';
  };

  programs.zsh = {
    shellAliases = {
      vpn-up = "sudo systemctl start wgnord";
      vpn-down = "sudo systemctl stop wgnord";
    };
  };
}
