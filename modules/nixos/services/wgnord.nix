{ lib, pkgs, config, ... }:
let
  inherit (lib) mkIf utils getExe' concatStringsSep;
  inherit (config.modules.system.networking) primaryInterface defaultGateway;
  cfg = config.modules.services.wgnord;
  ip = getExe' pkgs.iproute "ip";
in
mkIf cfg.enable
{
  assertions = utils.asserts [
    (defaultGateway != null)
    "Default gateway must be set to use wgnord"
  ];

  services.wgnord = {
    enable = true;
    tokenFile = config.age.secrets.nordToken.path;
    country = cfg.country;
    template = ''
      [Interface]
      PrivateKey = PRIVKEY
      Address = 10.5.0.2/32
      MTU = 1350
      DNS = 103.86.96.100 103.86.99.100
      PreUp = ${concatStringsSep ";" (map (route: "${ip} route add ${route} via ${defaultGateway} dev ${primaryInterface}") cfg.excludeSubnets)}
      PostDown = ${concatStringsSep ";" (map (route: "${ip} route del ${route} via ${defaultGateway} dev ${primaryInterface}") cfg.excludeSubnets)}

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
