{
  lib,
  pkgs,
  config,
  inputs,
}:
let
  inherit (lib)
    ns
    mkIf
    getExe
    getExe'
    concatMapStringsSep
    ;
  inherit (config.${ns}.system.networking) wiredInterface defaultGateway;
  cfg = config.${ns}.services.wgnord;
  ip = getExe' pkgs.iproute2 "ip";

  wgnord = pkgs.wgnord.overrideAttrs (old: {
    src = old.src.overrideAttrs {
      patches = (old.patches or [ ]) ++ [
        ../../../patches/stateless-wgnord.patch
      ];
    };
  });

  generateConfig = pkgs.writeShellScript "wgnord-generate-config" ''
    umask 0077
    [ -d /etc/wireguard ] && chmod 700 /etc/wireguard || mkdir /etc/wireguard
    # Wgnord is patched to only generate a config file
    ${getExe wgnord} connect ${cfg.country} "$(<${config.age.secrets.nordToken.path})" "${template}" "/etc/wireguard/wgnord.conf"
  '';

  template = pkgs.writeText "wgnord-template" ''
    [Interface]
    PrivateKey = PRIVKEY
    Address = 10.5.0.2/32
    MTU = 1350
    DNS = 103.86.96.100,103.86.99.100
    PreUp = ${
      concatMapStringsSep ";" (
        route: "${ip} route add ${route} via ${defaultGateway} dev ${wiredInterface}"
      ) cfg.excludeSubnets
    }
    PostDown = ${
      concatMapStringsSep ";" (
        route: "${ip} route del ${route} via ${defaultGateway} dev ${wiredInterface}"
      ) cfg.excludeSubnets
    }

    [Peer]
    PublicKey = SERVER_PUBKEY
    AllowedIPs = 0.0.0.0/0
    Endpoint = SERVER_IP:51820
    PersistentKeepalive = 25
  '';
in
[
  {
    guardType = "first";
    imports = [ inputs.vpn-confinement.nixosModules.default ];
    requirements = [ "system.networking.resolved" ];

    opts = with lib; {
      confinement.enable = mkEnableOption "Confinement Wireguard NordVPN";

      excludeSubnets = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = ''
          List of subnets to exclude from being routed through the VPN. Does
          not apply to the confinement VPN.
        '';
      };

      country = mkOption {
        type = types.str;
        default = "Switzerland";
        description = "The country to VPN to";
      };
    };

    asserts = [
      (cfg.excludeSubnets != [ ] -> defaultGateway != null)
      "Default gateway must be set to use wgnord subnet exclusion"
    ];

    networking.wg-quick.interfaces.wgnord = {
      autostart = false;
      configFile = "/etc/wireguard/wgnord.conf";
    };

    systemd.services.wg-quick-wgnord.preStart = generateConfig.outPath;

    programs.zsh.shellAliases = {
      wgnord-up = "sudo systemctl start wg-quick-wgnord";
      wgnord-down = "sudo systemctl stop wg-quick-wgnord";
    };
  }

  (mkIf cfg.confinement.enable {
    vpnNamespaces.wgnord = {
      enable = true;
      wireguardConfigFile = "/etc/wireguard/wgnord.conf";
      accessibleFrom = [ "127.0.0.1" ];
    };

    systemd.services.wgnord.serviceConfig.ExecStartPre = generateConfig;
  })
]
