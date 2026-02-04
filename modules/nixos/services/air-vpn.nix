{
  lib,
  cfg,
  pkgs,
  config,
  inputs,
}:
let
  inherit (config.age.secrets) airVpnConfig;
in
[
  {
    guardType = "first";
    imports = [ inputs.vpn-confinement.nixosModules.default ];
    requirements = [ "system.networking.resolved" ];
    opts.confinement.enable = lib.mkEnableOption "Confinement Wireguard AirVPN";

    networking.wg-quick.interfaces.air-vpn = {
      autostart = false;
      configFile = airVpnConfig.path;
    };

    programs.zsh.shellAliases = {
      air-vpn-up = "sudo systemctl start wg-quick-air-vpn";
      air-vpn-down = "sudo systemctl stop wg-quick-air-vpn";
    };

    ns.userPackages = [
      (pkgs.writeShellApplication {
        name = "air-vpn-switch-endpoint";
        runtimeInputs = [ pkgs.gnused ];
        text = ''
          if [ "$(id -u)" != "0" ]; then
             echo "This script must be run as root" >&2
             exit 1
          fi

          if [[ $# -ne 1 ]]; then
            echo "Usage: air-vpn-switch-endpoint <endpoint>" >&2
            exit 1
          fi

          sed -i "s/^Endpoint = .*:/Endpoint = $1:/" ${airVpnConfig.path}
          if systemctl restart air-vpn.service; then
            echo "Endpoint successfully switched to '$1'"
          else
            echo "VPN failed to start with endpoint '$1'"
          fi
        '';
      })
    ];
  }

  (lib.mkIf cfg.confinement.enable {
    vpnNamespaces.air-vpn = {
      enable = true;
      wireguardConfigFile = airVpnConfig.path;
      accessibleFrom = [ "127.0.0.1" ];
    };
  })
]
