{
  lib,
  config,
  inputs,
  ...
}:
let
  inherit (lib)
    ns
    mkIf
    mkMerge
    ;
  inherit (lib.${ns}) asserts;
  inherit (config.${ns}.system.networking) resolved;
  inherit (config.age.secrets) airVpnConfig;
  cfg = config.${ns}.services.air-vpn;
in
{
  imports = [ inputs.vpn-confinement.nixosModules.default ];

  config = mkMerge [
    (mkIf (cfg.enable || cfg.confinement.enable) {
      assertions = asserts [
        (airVpnConfig != null)
        "An Air VPN Wireguard config secret is needed"
      ];
    })

    (mkIf cfg.enable {
      assertions = asserts [
        resolved.enable
        "Wg-quick Air VPN requires systemd resolved to be enabled"
      ];

      networking.wg-quick.interfaces.air-vpn = {
        autostart = false;
        configFile = airVpnConfig.path;
      };

      programs.zsh.shellAliases = {
        air-vpn-up = "sudo systemctl start wg-quick-air-vpn";
        air-vpn-down = "sudo systemctl stop wg-quick-air-vpn";
      };
    })

    (mkIf cfg.confinement.enable {
      vpnNamespaces.air-vpn = {
        enable = true;
        wireguardConfigFile = airVpnConfig.path;
        accessibleFrom = [ "127.0.0.1" ];
      };
    })
  ];
}
