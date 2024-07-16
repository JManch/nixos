{
  lib,
  pkgs,
  config,
  ...
}:
let
  inherit (lib)
    mkIf
    utils
    getExe'
    concatMapStringsSep
    optionalString
    ;
  inherit (config.modules.system.networking) primaryInterface defaultGateway resolved;
  cfg = config.modules.services.wgnord;
  ip = getExe' pkgs.iproute "ip";
in
mkIf cfg.enable {
  assertions = utils.asserts [
    (defaultGateway != null)
    "Default gateway must be set to use wgnord"
    (cfg.splitTunnel -> (cfg.excludeSubnets == [ ]))
    "If split tunnel is enabled, wgnord exluded subnets will not work"
    (cfg.setDNS -> resolved.enable)
    "wgnord DNS server requires systemd resolved to be enabled"
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
      ${optionalString cfg.setDNS "DNS = 103.86.96.100 103.86.99.100"}
      PreUp = ${
        concatMapStringsSep ";" (
          route: "${ip} route add ${route} via ${defaultGateway} dev ${primaryInterface}"
        ) cfg.excludeSubnets
      }
      PostDown = ${
        concatMapStringsSep ";" (
          route: "${ip} route del ${route} via ${defaultGateway} dev ${primaryInterface}"
        ) cfg.excludeSubnets
      }

      ${optionalString cfg.splitTunnel ''
        PostUp = ip -4 rule delete table 51820
        PostUp = ip -4 rule delete table main suppress_prefixlength 0

        PostUp = ip -4 rule add not fwmark 51820 table 51820
        PostUp = ip -4 rule add not from 10.5.0.2 goto 32766

        PreDown = ip -4 rule delete table 51820
        PreDown = ip -4 rule delete goto 32766
      ''}

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
