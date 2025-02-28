{
  lib,
  cfg,
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
  }

  (lib.mkIf cfg.confinement.enable {
    vpnNamespaces.air-vpn = {
      enable = true;
      wireguardConfigFile = airVpnConfig.path;
      accessibleFrom = [ "127.0.0.1" ];
    };
  })
]
