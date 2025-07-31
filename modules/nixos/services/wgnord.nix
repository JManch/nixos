{
  lib,
  pkgs,
  config,
  inputs,
  username,
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
    if [[ ! -f /host-tmp/wgnord-country ]]; then
      echo "Failed to generate config: /tmp/wgnord-country does not exist" >&2
      exit 1
    fi
    [[ -d /etc/wireguard ]] && chmod 700 /etc/wireguard || mkdir /etc/wireguard
    # Wgnord is patched to only generate a config file
    ${getExe wgnord} connect "$(</host-tmp/wgnord-country)" "$(<${config.age.secrets.nordToken.path})" "${template}" "/etc/wireguard/wgnord.conf"
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
    };

    asserts = [
      (cfg.excludeSubnets != [ ] -> defaultGateway != null)
      "Default gateway must be set to use wgnord subnet exclusion"
    ];

    networking.wg-quick.interfaces.wgnord = {
      autostart = false;
      configFile = "/etc/wireguard/wgnord.conf";
    };

    systemd.services.wg-quick-wgnord = {
      preStart = generateConfig.outPath;
      # Service has PrivateTmp enabled but we still want to access host tmp for
      # country file
      serviceConfig.BindReadOnlyPaths = [ "/tmp:/host-tmp" ];
    };

    users.users.${username}.packages =
      map
        (
          type:
          pkgs.writeShellApplication {
            name = "wgnord-${type}";
            runtimeInputs = with pkgs; [
              gnugrep
              systemd
              libnotify
            ];
            text =
              (
                if type == "up" then # bash
                  ''
                    if [[ $# -ne 1 ]]; then
                      echo "Usage: wgnord-${type} <country>" >&2
                      exit 1
                    fi

                    if systemctl is-active --quiet wg-quick-wgnord; then
                      echo "VPN already running" >&2
                      exit 1
                    fi

                    rm -f /tmp/wgnord-country

                    # wgnord doesn't require an exact match, grep match is fine
                    if ! grep -iq -m 1 "$1" "${wgnord}/share/countries.txt"; then
                      echo "'$1' is not a valid country. List of countries:"
                      cat "${wgnord}/share/countries.txt"
                    fi

                    country=$(grep -i -m 1 "$1" "${wgnord}/share/countries.txt" | cut -d "	" -f 1)
                    echo "$country" > /tmp/wgnord-country
                    sudo systemctl start wg-quick-wgnord
                  ''
                else
                  ''
                    # Do not use sudo here because we want to be able to stop
                    # the VPN in a non-interactive context e.g. from Waybar and
                    # for this to work we need the polkit authentication
                    # dialog.
                    systemctl stop wg-quick-wgnord
                    rm -f /tmp/wgnord-country
                  ''
              )
              + ''
                notify-send --urgency=critical -t 5000 'NordVPN' "${
                  if type == "up" then "Connected to $country" else "Disconnected"
                }"
              '';
          }
        )
        [
          "up"
          "down"
        ];
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
