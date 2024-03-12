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
    # Allow all IPs apart from 192.168.0.0/16 and 10.0.0.0/8
    template = ''
      [Interface]
      PrivateKey = PRIVKEY
      Address = 10.5.0.2/32
      MTU = 1350
      DNS = 103.86.96.100 103.86.99.100

      [Peer]
      PublicKey = SERVER_PUBKEY
      AllowedIPs = 0.0.0.0/5, 8.0.0.0/7, 11.0.0.0/8, 12.0.0.0/6, 16.0.0.0/4, 32.0.0.0/3, 64.0.0.0/2, 128.0.0.0/2, 192.0.0.0/9, 192.128.0.0/11, 192.160.0.0/13, 192.169.0.0/16, 192.170.0.0/15, 192.172.0.0/14, 192.176.0.0/12, 192.192.0.0/10, 193.0.0.0/8, 194.0.0.0/7, 196.0.0.0/6, 200.0.0.0/5, 208.0.0.0/4, 224.0.0.0/3, ::/0
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
