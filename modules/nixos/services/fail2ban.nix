{ lib, config, ... }:
let
  inherit (lib) ns mkIf mkForce;
  cfg = config.${ns}.services.fail2ban;
in
mkIf cfg.enable {
  services.fail2ban = {
    enable = true;
    maxretry = 3;
    # WARN: Need to change this if I switch to nftables
    banaction = "iptables[type=multiport]";
    banaction-allports = "iptables[type=allports]";
    bantime-increment.enable = true;
    # Upstream prepends ignoreips with 127.0.0.1/8 but the ignoreself option
    # (true by default) covers this for my use case
    jails.DEFAULT.settings.ignoreip = mkForce "";
  };
}
