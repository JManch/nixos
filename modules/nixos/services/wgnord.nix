{
  ns,
  lib,
  pkgs,
  config,
  inputs,
  ...
}:
let
  inherit (lib)
    mkIf
    mkMerge
    getExe
    getExe'
    concatMapStringsSep
    ;
  inherit (lib.${ns}) asserts;
  inherit (config.${ns}.system.networking) wiredInterface defaultGateway resolved;
  cfg = config.${ns}.services.wgnord;
  ip = getExe' pkgs.iproute "ip";
  wg-quick = getExe' pkgs.wireguard-tools "wg-quick";
  wgnord = pkgs.wgnord.overrideAttrs (old: {
    src = old.src.overrideAttrs {
      patches = (old.patches or [ ]) ++ [
        ../../../patches/statelessWgnord.patch
      ];
    };
  });

  generateConfig = pkgs.writeShellScript "wgnord-generate-config" ''
    umask 0077
    # Wgnord is patched so all it does is generate a config file
    mkdir -p /etc/wireguard
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
{
  imports = [ inputs.vpn-confinement.nixosModules.default ];

  config = mkMerge [
    (mkIf (cfg.enable || cfg.confinement.enable) {
      assertions = asserts [
        (config.age.secrets.nordToken != null)
        "The Nord token secret is required for wgnord VPN"
      ];
    })

    (mkIf cfg.enable {
      assertions = asserts [
        ((cfg.excludeSubnets != [ ]) -> (defaultGateway != null))
        "Default gateway must be set to use wgnord subnet exclusion"
        (resolved.enable)
        "Wg-quick Nord VPN requires systemd resolved to be enabled"
      ];

      systemd.services.wg-quick-wgnord = {
        unitConfig = {
          Description = "Nord WireGuard Quick VPN";
          After = [ "network-online.target" ];
          Wants = [ "network-online.target" ];
          StartLimitBurst = 3;
          StartLimitIntervalSec = 30;
        };

        serviceConfig = {
          Type = "oneshot";

          ExecStartPre = generateConfig;
          ExecStart = "${wg-quick} up wgnord";
          ExecStop = "${wg-quick} down wgnord";
          RemainAfterExit = "yes";

          Restart = "on-failure";
          RestartSec = 10;
        };
      };

      programs.zsh = {
        shellAliases = {
          vpn-up = "sudo systemctl start wg-quick-wgnord";
          vpn-down = "sudo systemctl stop wg-quick-wgnord";
        };
      };
    })

    (mkIf cfg.confinement.enable {
      vpnNamespaces.wgnord = {
        enable = true;
        wireguardConfigFile = "/etc/wireguard/wgnord.conf";
        accessibleFrom = [
          "127.0.0.1"
        ];
      };

      systemd.services.wgnord.serviceConfig.ExecStartPre = generateConfig;
    })
  ];
}
