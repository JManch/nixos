{ lib, config, ... }:
let
  inherit (lib) mkIf;
  cfg = config.modules.services.fail2ban;
in
mkIf cfg.enable
{
  services.fail2ban = {
    enable = true;
    maxretry = 3;
    ignoreIP = cfg.ignoredIPs;
    bantime-increment.enable = true;
  };
}
